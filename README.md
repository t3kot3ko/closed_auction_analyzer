# closed_auction_analyzer

ヤフオク(http://auctions.yahoo.co.jp/) 落札相場調査をコマンドラインから行うための gem．

## できること
- 終了したオークションの検索
  - 価格帯，新品／中古，個人／ストアなどのフィルタリングに対応
- 落札価格の平均算出
  - ただ単に平均落札価格を計算する．
  - Jenkins で定常監視すると価格変動を検知，予測することができるかも
- 落札価格帯ヒストグラム取得
  - 落札価格帯の分布を取得する．
  - 出品戦略を立てる材料にする