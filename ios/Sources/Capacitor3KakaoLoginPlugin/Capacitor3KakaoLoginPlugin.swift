import Foundation
import Capacitor
import UIKit

import KakaoSDKAuth
import KakaoSDKUser

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(Capacitor3KakaoLoginPlugin)
public class Capacitor3KakaoLoginPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "Capacitor3KakaoLoginPlugin"
    public let jsName = "Capacitor3KakaoLogin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "initializeKakao", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "kakaoLogin", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "kakaoLogout", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "kakaoUnlink", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sendLinkFeed", returnType: CAPPluginReturnPromise),
    ]

    private let implementation = Capacitor3KakaoLogin()

    // MARK: - 유실 콜백 백스톱 (saju.ai#24)
    //
    // `loginWithKakaoTalk` 은 카카오톡으로 앱을 전환하고, 완료 핸들러는 **리다이렉트 URL 이 와야만**
    // 실행된다. 사용자가 카카오톡의 "취소" 버튼이 아니라 앱 스위처·홈·뒤로 제스처로 돌아오면 URL 이
    // 오지 않아 completion 이 영영 호출되지 않고, `CAPPluginCall` 도 JS promise 도 settle 되지 않는다.
    // JS 쪽에서는 로그인 오버레이가 걷히지 않아 화면이 잠긴다.
    //
    // SDK 소스가 확정 신호를 준다 — `AuthController.handleOpenUrl` 은 리다이렉트를 받는 즉시
    // `authorizeWithTalkCompletionHandler` 를 **nil 로 비우고**(AuthController.swift:203) 토큰 교환을
    // 시작한다. iOS 의 URL 오픈 순서는 willEnterForeground → application(_:open:) → didBecomeActive 다.
    // 따라서 **didBecomeActive 시점에 핸들러가 아직 non-nil 이면 리다이렉트가 온 적이 없다**는 뜻이고,
    // 성공 경로에서는 그 시점에 이미 nil 이므로 성공을 훔칠 수 없다.
    //
    // 다만 핸들러는 `:106`·`:499` 에서 설정되고 `:203` 한 곳에서만 해제되므로, 리다이렉트 없이 끝난
    // 모든 경로에서 **프로세스 수명 내내 non-nil 로 남는다**. 그래서 핸들러 하나만 보면 안 되고
    // 아래 네 조건을 모두 만족할 때만 발동한다.
    //
    // 모든 접근은 메인 큐다 — 알림은 메인에서 오고 `kakaoLogin` 도 메인으로 디스패치한다.

    /// 진행 중인 `kakaoLogin` 호출. 결과가 정상 도착하면 즉시 비운다.
    private var pendingLoginCall: CAPPluginCall?
    /// 이번 로그인이 실제로 백그라운드를 다녀왔는가. 제어센터·알림센터·전화 수신 복귀는
    /// `didEnterBackground` 를 내지 않으므로, 카카오톡이 뜨기 전(`open(url)` 은 비동기다) 사용자가
    /// 제어센터를 내렸다 올리는 오탐을 이 조건이 닫는다. JS 의 `visibilitychange` 와 달리 이 알림은
    /// 배달이 보장된다.
    private var didBackgroundDuringLogin = false
    /// 이번 로그인이 카카오톡 전환(talk) 분기였는가. 웹 시트(`loginWithKakaoAccount`) 분기는
    /// `authorizeWithTalkCompletionHandler` 를 쓰지도 지우지도 않으므로, 앞선 talk 로그인이 남긴
    /// stale non-nil 때문에 멀쩡한 웹 시트 로그인이 취소되는 것을 막는다.
    private var usedTalkBranch = false

    override public func load() {
        // 로그인마다 등록/해제하면 해제 누락 경로가 생긴다 — 1회 등록하고 `pendingLoginCall` 이 게이트다.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnterBackground() {
        guard pendingLoginCall != nil else { return }
        didBackgroundDuringLogin = true
    }

    @objc private func appDidBecomeActive() {
        guard let call = pendingLoginCall,
              usedTalkBranch,
              didBackgroundDuringLogin,
              AuthController.shared.authorizeWithTalkCompletionHandler != nil
        else { return }

        clearPendingLogin()
        // 살려 두면 나중에 도착한 옛 리다이렉트가 토큰 교환을 돌려 **이미 reject 된 call 에 resolve** 를
        // 건다. nil 로 만들면 handleOpenUrl 이 false 를 반환해 URL 이 조용히 버려진다(재탭으로 복구).
        AuthController.shared.authorizeWithTalkCompletionHandler = nil
        call.reject("Kakao login was abandoned without a redirect callback.", "SIGN_IN_CANCELLED")
    }

    private func clearPendingLogin() {
        pendingLoginCall = nil
        didBackgroundDuringLogin = false
        usedTalkBranch = false
    }

    //네이티브는 app delegate에서 초기화함
    @objc func initializeKakao(_ call: CAPPluginCall) {
        call.resolve([
            "value": "done"
        ])
    }

    @objc func kakaoLogin(_ call: CAPPluginCall) {

        DispatchQueue.main.async {
            // 이전 호출이 결과 없이 남아 있으면 먼저 정리한다. 안 하면 그 JS promise 가 영원히 pending 으로
            // 남아 — 지금 고치려는 결함과 같은 부류가 그대로 남는다.
            if let stale = self.pendingLoginCall {
                self.clearPendingLogin()
                stale.reject("Kakao login was superseded by a new attempt.", "SIGN_IN_CANCELLED")
            }

            // 분기는 여기서 한 번만 판정해 implementation 에 넘긴다 — 양쪽에서 각각 물으면 그 사이에
            // 가용성이 바뀔 때 백스톱의 판단 근거와 실제 분기가 어긋난다.
            let useTalk = UserApi.isKakaoTalkLoginAvailable()
            self.pendingLoginCall = call
            self.didBackgroundDuringLogin = false
            self.usedTalkBranch = useTalk

            self.implementation.kakaoLogin(call, useTalk: useTalk) { [weak self] in
                guard let self, self.pendingLoginCall === call else { return }
                self.clearPendingLogin()
            }
        }
    }

    @objc func kakaoLogout(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.kakaoLogout(call)
        }

    }

    @objc func kakaoUnlink(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.kakaoUnlink(call)
        }
    }

    @objc func sendLinkFeed(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.implementation.sendLinkFeed(call)
        }
    }
}
