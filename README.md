# CN Creative Studio｜數位視覺創作

手機優先的個人設計作品集網站，使用 GitHub Pages 發布。

## 網站內容
- 商業宣傳與商品視覺
- 餐飲、美容美體與社群設計
- 遊戲廣告設計
- AI 視覺與動態內容
- Instagram 與 Linkbio 合作入口

## 發布方式
Repository 的 Settings → Pages → Build and deployment → Source 選擇 **GitHub Actions**。
本專案已加入 `.github/workflows/pages.yml`，推送至 `main` 時會自動執行部署。

預期網址：https://maoniu1018-star.github.io/cn-creative-studio/

## 作品圖片
請將 `CN_Creative_Studio_作品集網站圖片素材.zip` 上傳到 Repository 根目錄，並命名為 `portfolio-assets.zip`。GitHub Actions 會在部署時自動解壓縮到 `assets/`，圖片即可顯示。