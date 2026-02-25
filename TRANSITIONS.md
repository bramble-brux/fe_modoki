# 状態遷移図 (State Transition Diagram)

修正された要件に基づいた、タイマーの状態遷移図です。

```mermaid
stateDiagram-v2
    [*] --> Work_Counting
    
    state Work_Counting {
        [*] --> Work_Normal: 開始
        Work_Normal --> Work_Extended: 設定時間超過
        Work_Normal --> [*]: モード切替
        Work_Extended --> [*]: モード切替
    }
    
    Work_Counting --> Free_Counting: モード切替ボタン
    
    state Free_Counting {
        [*] --> Free_Running: 開始
        Free_Running --> Free_Alert: 設定時間到達
        Free_Alert --> Free_Alert: アラート鳴動継続
        Free_Alert --> [*]: 停止ボタン押下
    }
    
    Free_Counting --> Work_Counting: アラート停止後 (自動移行)
    
    state Settings {
        [*] --> Editing
        Editing --> [*]: 保存して閉じる
    }
    
    Work_Counting --> Settings: ギアボタン
    Free_Counting --> Settings: ギアボタン
```

## 主要な遷移の解説

1.  **仕事モード (Work Mode)**:
    - カウントアップを行い、設定時間を過ぎると自動的に「延長状態」に遷移します。
    - 延長状態では文字色がオレンジに変わりますが、タイマーは止まりません。

2.  **自由モード (Free Mode)**:
    - カウントアップを行い、設定時間に達すると「アラート鳴動状態」になります。
    - アラートは「停止ボタン」を押すまで鳴り続けます。

3.  **自動移行**:
    - 自由モードでアラートを停止させると、**直ちに仕事モードへ移行し、タイマーが自動でスタート**します。
