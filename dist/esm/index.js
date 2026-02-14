import { registerPlugin } from '@capacitor/core';
const Capacitor3KakaoLogin = registerPlugin('Capacitor3KakaoLogin', {
    web: () => import('./web').then(m => new m.Capacitor3KakaoLoginWeb()),
});
export * from './definitions';
export { Capacitor3KakaoLogin };
//# sourceMappingURL=index.js.map