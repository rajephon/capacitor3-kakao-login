package com.fumi.capacitor3_kakao_login;

import android.content.Context;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;
import com.getcapacitor.JSObject;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.kakao.sdk.auth.model.OAuthToken;
import com.kakao.sdk.common.KakaoSdk;
import com.kakao.sdk.common.model.AuthError;
import com.kakao.sdk.common.model.AuthErrorCause;
import com.kakao.sdk.common.model.ClientError;
import com.kakao.sdk.common.model.ClientErrorCause;
import com.kakao.sdk.share.ShareClient;
import com.kakao.sdk.template.model.Button;
import com.kakao.sdk.template.model.Content;
import com.kakao.sdk.template.model.FeedTemplate;
import com.kakao.sdk.template.model.Link;
import com.kakao.sdk.user.UserApiClient;
import java.util.ArrayList;
import kotlin.Unit;
import kotlin.jvm.functions.Function2;

public class Capacitor3KakaoLogin {

    private static final String TAG = "Capacitor3KakaoLogin";
    AppCompatActivity activity;

    public Capacitor3KakaoLogin(AppCompatActivity activity) {
        this.activity = activity;
    }

    /**
     * 사용자 취소로 취급할 에러 두 갈래 — iOS `isUserCancellation` 과 같은 기준.
     * - ClientError(Cancelled): 간편로그인 "취소", 카카오톡·Custom Tabs 에서 뒤로가기
     * - AuthError(AccessDenied): 동의 화면에서 "취소"(error=access_denied)
     */
    static boolean isUserCancellation(Throwable error) {
        if (error instanceof ClientError) {
            return ((ClientError) error).getReason() == ClientErrorCause.Cancelled;
        }
        if (error instanceof AuthError) {
            return ((AuthError) error).getReason() == AuthErrorCause.AccessDenied;
        }
        return false;
    }

    public void kakaoLogin(PluginCall call) {
        // 응답은 iOS 와 같은 KakaoLoginResult(accessToken·idToken·refreshToken)다. 토큰은 로그에 남기지 않는다.
        Function2<OAuthToken, Throwable, Unit> handleResult = (oAuthToken, error) -> {
            if (error != null) {
                Log.e(TAG, "로그인 실패", error);
                // 사용자 취소는 코드로 구분한다 — JS 는 문구가 아니라 code 로 취소를 식별한다(iOS 와 같은 계약).
                String code = isUserCancellation(error) ? "SIGN_IN_CANCELLED" : null;
                call.reject(error.toString(), code, error instanceof Exception ? (Exception) error : null);
            } else if (oAuthToken != null) {
                JSObject ret = new JSObject();
                ret.put("accessToken", oAuthToken.getAccessToken());
                ret.put("idToken", oAuthToken.getIdToken() != null ? oAuthToken.getIdToken() : "");
                ret.put("refreshToken", oAuthToken.getRefreshToken());
                call.resolve(ret);
            } else {
                call.reject("no_data");
            }
            return null;
        };

        if (UserApiClient.getInstance().isKakaoTalkLoginAvailable(this.activity)) {
            UserApiClient.getInstance().loginWithKakaoTalk(this.activity, handleResult);
        } else {
            UserApiClient.getInstance().loginWithKakaoAccount(this.activity, handleResult);
        }
    }

    public void kakaoLogout(PluginCall call) {
        UserApiClient
                .getInstance()
                .logout(
                        error -> {
                            JSObject ret = new JSObject();
                            ret.put("value", "done");
                            call.resolve(ret);
                            return null;
                        }
                );
    }

    public void kakaoUnlink(PluginCall call) {
        UserApiClient
                .getInstance()
                .unlink(
                        error -> {
                            JSObject ret = new JSObject();
                            ret.put("value", "done");
                            call.resolve(ret);
                            return null;
                        }
                );
    }

    public void sendLinkFeed(PluginCall call) {
        Link link = new Link(call.getString("image_link_url"), call.getString("image_link_url"), null, null);
        Content content = new Content(call.getString("title"), call.getString("image_url"), link, call.getString("description"));
        ArrayList<Button> buttons = new ArrayList<>();
        buttons.add(new Button(call.getString("button_title"), link));
        FeedTemplate feed = new FeedTemplate(content, null, null, buttons);
        ShareClient
                .getInstance()
                .shareDefault(
                        this.activity,
                        feed,
                        (linkResult, error) -> {
                            if (error != null) {} else if (linkResult != null) {
                                this.activity.startActivity(linkResult.getIntent());
                            }

                            JSObject ret = new JSObject();
                            ret.put("value", "done");
                            call.resolve(ret);
                            return null;
                        }
                );
    }
}
