# closed_auction_analyzer

ヤフオク(http://auctions.yahoo.co.jp/) 落札相場調査を行うコマンドラインツール

## できること
- 終了したオークションの検索
  - 価格帯，新品／中古，個人／ストアなどのフィルタリングに対応
- 落札価格の平均算出
  - ただ単に平均落札価格を計算する
  - Jenkins で定常監視すると価格変動を検知，予測することができるかも
- 落札価格帯ヒストグラム取得
  - 落札価格帯の分布を取得する
  - 出品戦略を立てる材料にする

# 使い方
## 共通のコマンドラインオプション
|オプション|説明|制限|デフォルト|
|:---------|:---|:---|:---------|
|`--max N`|最大金額|整数|（指定なし）|
|`--min N`|最小金額|整数|（指定なし）|
|`--sort`|ソート種類|`cbids`...落札金額，`bids`...入札数，`end`...落札日時|`cbids`|
|`--order`|ソート順|`a`...昇順，`d`...降順|`d`|
|`--page N`|ページ数|整数|`1`|
|`--all`|全ページを検索する| - |（指定なし）|

## 共通の環境変数
* `DISABLE_LOGGER`
  * ログ表示を無効化する (`DISABLE_LOGGER=true`)

## search -- 終了したオークションの検索
```
caa search "<search word>" [options]
```

例えば，10000円以上30000円以下で落札された商品の落札日時，タイトル，落札金額を全件表示したい場合：
```
caa search "happy hacking professional" --min 10000 --max 30000 --outputs end_date title end_price --all
#=>
```

### オプション
|オプション|説明|制限|デフォルト|
|:---------|:---|:---|:---------|
|`--outputs`|表示カラム|`url`, `title`, `end_price`, `start_price`, `end_date`, `end_time`, `bid_count` （省略した場合はすべて）|すべて|
|`--format`|表示フォーマット|`csv`, `json`, `yaml`|`csv`|

## avr -- 落札価格平均の計算
```
caa avr "<search word>" [options]

caa avr "happy hacking professional" --min 10000 --max 30000 --all #=> 16601.5625
```

# histogram -- 落札価格分布のヒストグラム表示
```
caa avr "<search word>" [options]

caa histogram "happy hacking professional" --min 10000 --max 30000 --all 
  #=> 
   9000 ~ 10000: 1
   10000 ~ 11000: 2
   11000 ~ 12000: 0
   12000 ~ 13000: 3
   13000 ~ 14000: 5
   14000 ~ 15000: 3
   ...

caa histogram "happy hacking professional" --min 10000 --max 30000 --all --star
  #=> 
   9000 ~ 10000: *
   10000 ~ 11000: **
   11000 ~ 12000:
   12000 ~ 13000: ***
   13000 ~ 14000: *****
   14000 ~ 15000: ***
   ...
```
### オプション
|オプション|説明|制限|デフォルト|
|:---------|:---|:---|:---------|
|`--star`|ヒストグラムの表示|指定するとアスタリスクで表示．指定しないと数字で表示|（指定なし）|
|`--interval N`|横軸間隔|整数|`10 ** (digits(max - min) - 2)` （`digits(N)` は `N` の桁数）|
|`--scale N`|倍率（ヒストグラムが `1/N` 倍に圧縮される）|整数|1|


