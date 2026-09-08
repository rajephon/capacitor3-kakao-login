import Foundation
import Capacitor

import KakaoSDKAuth
import KakaoSDKUser
import KakaoSDKCommon
import KakaoSDKShare
import KakaoSDKTemplate


@objc public class Capacitor3KakaoLogin: NSObject {
    /// 사용자 취소로 취급할 SdkError 두 갈래.
    /// - ClientFailed(.Cancelled): 간편로그인 "취소" 버튼(error=cancelled), ASWebAuthenticationSession 닫기
    ///   (카카오톡 실행 실패는 .NotSupported 라 취소가 아닌 일반 실패로 남는다 — 의도된 동작)
    /// - AuthFailed(.AccessDenied): 동의 화면에서 "취소"(error=access_denied) — SDK 주석: "사용자가 동의 화면에서 카카오 로그인을 취소한 경우"
    ///   첫 로그인·연결 끊기 후 재로그인이 모두 동의 화면을 거치므로 실제로는 이쪽이 더 흔하다.
    static func isUserCancellation(_ error: SdkError) -> Bool {
        switch error {
        case .ClientFailed(reason: .Cancelled, errorMessage: _),
             .AuthFailed(reason: .AccessDenied, errorInfo: _):
            return true
        default:
            return false
        }
    }

    /// - Parameters:
    ///   - useTalk: 카카오톡 전환 분기를 쓸지. 호출부(플러그인)가 이미 판정한 값을 받는다 — 여기서 다시
    ///     `isKakaoTalkLoginAvailable()` 을 물으면 그 사이 가용성이 바뀔 때 백스톱의 판단 근거(saju.ai#24)와
    ///     실제 분기가 어긋난다.
    ///   - onSettled: 결과가 도착했음을 알린다. 플러그인이 보관 중인 `CAPPluginCall` 을 놓아주는 신호이며,
    ///     완료 핸들러가 영영 호출되지 않는 경우에는 당연히 불리지 않는다 — 그게 백스톱이 잡는 상황이다.
    @objc public func kakaoLogin(_ call: CAPPluginCall, useTalk: Bool, onSettled: @escaping () -> Void) -> Void {

        let handleResult: (OAuthToken?, Error?) -> Void = { oauthToken, error in
            onSettled()
            if let error = error {
                // 사용자 취소는 코드로 구분한다. SdkError 는 LocalizedError 를 채택하지 않아
                // localizedDescription 이 "…SdkError error 0." 뿐이라 JS 가 문구로는 취소를 식별할 수 없다
                // (Capacitor 브리지는 3번째 인자 error 객체를 JS 로 넘기지 않는다).
                if let sdkError = error as? SdkError, Capacitor3KakaoLogin.isUserCancellation(sdkError) {
                    call.reject(error.localizedDescription, "SIGN_IN_CANCELLED", error)
                    return
                }
                call.reject(error.localizedDescription, nil, error)
                return
            }
            call.resolve([
                "accessToken": oauthToken?.accessToken ?? "",
                "idToken": oauthToken?.idToken ?? "",
                "refreshToken": oauthToken?.refreshToken ?? "",
            ])
        }

        if useTalk {
            UserApi.shared.loginWithKakaoTalk(completion: handleResult)
        } else {
            UserApi.shared.loginWithKakaoAccount(completion: handleResult)
        }
    }
    
    @objc public func kakaoLogout(_ call: CAPPluginCall) -> Void {

        UserApi.shared.logout {(error) in
            if let error = error {
                print(error)
                call.reject("error")
            }
            else {

                call.resolve([
                    "value": "done"
                ])
            }
        }
    }
    
    
    
    @objc public func kakaoUnlink(_ call: CAPPluginCall) -> Void {

        UserApi.shared.unlink {(error) in
            if let error = error {
                print(error)
                call.reject("error")
            }
            else {

                call.resolve([
                    "value": "done"
                ])
            }
        }
    }
    
    
    @objc public func sendLinkFeed(_ call: CAPPluginCall) -> Void {

        let title = call.getString("title") ?? ""
        let description = call.getString("description") ?? ""
        let image_url = call.getString("image_url") ?? ""
        let image_link_url = call.getString("image_link_url") ?? ""
        let button_title = call.getString("button_title") ?? ""

        
        
        let link = Link(webUrl: URL(string:image_link_url),
                        mobileWebUrl: URL(string:image_link_url))

        let button = Button(title: button_title, link: link)
       
        let content = Content(title: title,
                                imageUrl: URL(string:image_url)!,
                                description: description,
                                link: link)
        let feedTemplate = FeedTemplate(content: content, social: nil, buttons: [button])

//        //메시지 템플릿 encode
//        if let feedTemplateJsonData = (try? SdkJSONEncoder.custom.encode(feedTemplate)) {
//
//        //생성한 메시지 템플릿 객체를 jsonObject로 변환
//            if let templateJsonObject = SdkUtils.toJsonObject(feedTemplateJsonData) {
//                ShareApi.shared.shareDefault(templateObject:templateJsonObject) {(linkResult, error) in
//                    if let error = error {
//                        print(error)
//                        call.reject("error")
//                    }
//                    else {
//
//                        //do something
//                        guard let linkResult = linkResult else { return }
//                        UIApplication.shared.open(linkResult.url, options: [:], completionHandler: nil)
//
//                        call.resolve([
//                            "value": "done"
//                        ])
//                    }
//                }
//            }
//
//        }
        
        
        if let feedTemplateJsonData = (try? SdkJSONEncoder.custom.encode(feedTemplate)) {

        //jsonObject
            if let templateJsonObject = SdkUtils.toJsonObject(feedTemplateJsonData) {
                ShareApi.shared.shareDefault(templateObject:templateJsonObject) { [weak self] (sharingResult, error) in
                    if let error = error {
                        print(error)
                        call.reject("error")
                    }
                    else {
                        //do something
                        guard let sharingResult = sharingResult else { return }
                        UIApplication.shared.open(sharingResult.url, options: [:], completionHandler: nil)
                    
                        
                        call.resolve([
                            "value": "done"
                        ])
                    }
                }
            }
        }
        
        
        
    }
}
