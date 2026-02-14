import { WebPlugin } from '@capacitor/core';
import type { Capacitor3KakaoLoginPlugin } from './definitions';
declare global {
    interface Window {
        Kakao: any;
    }
}
export declare class Capacitor3KakaoLoginWeb extends WebPlugin implements Capacitor3KakaoLoginPlugin {
    private kakaoScriptId;
    web_key: any;
    private redirectUri;
    initializeKakao(options: {
        app_key: string;
        web_key: string;
    }): Promise<{
        value: string;
    }>;
    kakaoLogin(options?: {
        redirectUri?: string;
        webSdkVersion?: 'v1' | 'v2';
    }): Promise<{
        value: string;
    }>;
    handleKakaoCallback(): Promise<{
        value: string;
    }>;
    kakaoLogout(): Promise<{
        value: string;
    }>;
    kakaoUnlink(): Promise<{
        value: string;
    }>;
    sendLinkFeed(options: {
        title: string;
        description: string;
        image_url: string;
        image_link_url: string;
        button_title: string;
    }): Promise<{
        value: string;
    }>;
    private getAccessTokenFromCode;
    private removeKakaoSdk;
    private loadKakaoSdk;
}
