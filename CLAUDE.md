# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Capacitor plugin for Kakao Login (despite the name `capacitor3-kakao-login`, it targets **Capacitor 8**). Provides Kakao authentication and KakaoLink sharing across Web, iOS (Swift), and Android (Java).

## Build & Development Commands

```bash
npm run build          # Clean + TypeScript compile + Rollup bundle
npm run build-b        # TypeScript compile only (to dist/esm/)
npm run build-c        # Rollup bundle only (dist/esm/ → dist/plugin.js, dist/plugin.cjs.js)
npm run watch          # TypeScript watch mode

npm run lint           # ESLint + Prettier check + SwiftLint
npm run fmt            # Auto-fix: ESLint + Prettier + SwiftLint

npm run verify         # Build & validate all platforms (iOS + Android + Web)
npm run verify:ios     # Pod install + Xcode build
npm run verify:android # Gradle clean build test
npm run verify:web     # Same as npm run build

npm run docgen         # Generate API docs into README.md
npm run release        # Publish to npm via np
```

## Architecture

### Plugin Structure (Capacitor Pattern)

- **`src/definitions.ts`** — TypeScript interface defining the plugin API (`Capacitor3KakaoLoginPlugin`)
- **`src/index.ts`** — Plugin registration via `registerPlugin()`, lazy-loads web implementation
- **`src/web.ts`** — Web implementation extending `WebPlugin`
- **`ios/Plugin/Capacitor3KakaoLoginPlugin.swift`** — iOS plugin bridge (CAPPlugin, routes calls to implementation)
- **`ios/Plugin/Capacitor3KakaoLogin.swift`** — iOS native implementation using KakaoSDK
- **`android/.../Capacitor3KakaoLoginPlugin.java`** — Android plugin bridge (@CapacitorPlugin, routes calls)
- **`android/.../Capacitor3KakaoLogin.java`** — Android native implementation using Kakao SDK

### Web SDK Dual Version Support

The web implementation supports two Kakao SDK versions:
- **v1** (default was v1, now v2): Callback-based `Kakao.Auth.login()` — returns access token directly
- **v2** (default): Redirect-based `Kakao.Auth.authorize()` — redirects to Kakao, then `handleKakaoCallback()` exchanges auth code for token via REST API (`kauth.kakao.com/oauth/token`)

The SDK script is dynamically loaded/removed between calls to handle version switching.

### Plugin API Methods

| Method | Purpose |
|---|---|
| `initializeKakao({app_key, web_key})` | Initialize with Kakao app credentials |
| `kakaoLogin({redirectUri?, webSdkVersion?})` | Login (web: v1 callback or v2 redirect) |
| `handleKakaoCallback()` | Exchange auth code for token after v2 redirect |
| `kakaoLogout()` | Logout from Kakao |
| `kakaoUnlink()` | Unlink Kakao account |
| `sendLinkFeed({title, description, ...})` | Share feed via KakaoLink/KakaoTalk |

### Native SDK Versions

- Android: Kakao SDK 2.23.0 (Maven: `com.kakao.sdk:v2-all`)
- iOS CocoaPods: KakaoSDK ~2.22.0 (KakaoSDKCommon, KakaoSDKAuth, KakaoSDKUser, KakaoSDKTalk, KakaoSDKShare, KakaoSDKTemplate)
- iOS SPM: KakaoSDK 2.23.0+ via Package.swift

### Build Pipeline

TypeScript (`src/`) → `tsc` → `dist/esm/` (ESM) → Rollup → `dist/plugin.js` (IIFE) + `dist/plugin.cjs.js` (CJS)

### Platform Targets

- iOS: deployment target 15.0, Swift 5.1
- Android: minSdk 24, compileSdk 36, Java 17
- Node: 22.14.0
