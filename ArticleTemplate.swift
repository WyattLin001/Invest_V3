// MARK: - ArticleTemplate.swift
import Foundation

enum ArticleTemplate {
    static let richTextPlaceholder = """
<h1>輸入標題</h1>
<p><b>作者：</b>你的名字<br><b>Email：</b>you@email.com</p>
<hr>
<h2>摘要</h2>
<p>300 字...</p>
<h2>正文</h2>
<p>第一段...[1]</p>
<img src='https://via.placeholder.com/500x250'>
<p>圖 1. 圖片說明</p>
<table><tr><th>A</th><th>B</th></tr><tr><td>10</td><td>20</td></tr></table>
<p>表 1. 數據比較</p>
<h2>關鍵字</h2>
<p>keyword1, keyword2</p>
<hr>
<h2>參考資料</h2>
<p>[1] 來源網址</p>
"""
    
    static func richTextPlaceholder(author: String, email: String) -> String {
        return richTextPlaceholder
            .replacingOccurrences(of: "你的名字", with: author)
            .replacingOccurrences(of: "you@email.com", with: email)
    }
    
    static func defaultText(author: String, email: String) -> String {
"""
# 〈請輸入文章標題〉

**作者：** \(author)  
**Email：** \(email)

---

## 摘要  
在此輸入 300–400 字摘要。

## 文章內容  
第一段… 如圖所示[1]。

![圖 1. 圖片說明](https://via.placeholder.com/600x300)

圖 1. 圖片說明  

| 指標 | A | B |
|------|---|---|
| 數值 | 10 | 20 |

表 1. 指標比較  

## 關鍵字  
`關鍵字1`, `關鍵字2`, `關鍵字3`

## 參考資料  
[1] 某某著 (2024). *我的研究*.  
[2] https://example.com/article-2
"""
    }

    static func extractTitle(from md: String) -> String {
        md.split(separator: "\n").first?.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces) ?? "Untitled"
    }

    static func extractPlainText(from md: String) -> String {
        md.replacingOccurrences(of: #"#[^\n]+\n"#, with: "", options: .regularExpression)
          .replacingOccurrences(of: #"\*\*.+?\*\*"#, with: "", options: .regularExpression)
    }
} 