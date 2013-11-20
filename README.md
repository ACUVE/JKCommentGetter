# JKCommentGetter

## これは何？
ニコニコ実況のコメントをダウンロードするスクリプトです。
単体で利用するためには getCookie メソッドの実装が必要です。実装の詳細はソースコードをご覧ください。

## コマンド
```
ruby *******.rb チャンネル 取得時間範囲のはじめ 取得時間範囲のおわり [option....]
```

### 必須引数：
- チャンネル："jk1"など
- 取得時間範囲のはじめ：Unix時または、YYYYMMDDhhmmss形式でも受け付けます。具体的には14桁でない時はUnix時として扱います。
- 取得時間範囲のおわり：上に同じ。

### オプション：
#### `-m sec`, `--margin sec`
  取得時間範囲の前後を指定秒だけ広げます。負の値も受け付けます。

#### `-s sec`, `--start-margin sec`
  取得時間範囲のはじめを指定秒だけ早くします。`-m`による指定よりも優先されます。負の値も受け付けます。

#### `-e sec`, `--end-margin sec`
  取得時間範囲のおわりを指定秒だけ遅くします。`-m`による指定よりも優先されます。負の値も受け付けます。

#### `-f [filename]`, `--file [filename]`
  取得結果を`filename`に出力します。  
  `filename`を省略した場合、「(一番始めのコメントのUnix時).(フォーマット固有の拡張子)」に出力されます。
  オプション自体を省略した場合、標準出力に出力します。

#### `-x`, `--xml`
  出力フォーマットをXMLにします。chatタグ以外の情報は失われています。  
  このオプションを指定すると、`-c`および`-t`が無視されます。`-j`と同時に指定できません。

#### `-j`, `--jkl`
  出力フォーマットをJikkyoRec互換っぽくします。chatタグ以外の情報は失われています。  
  このオプションを指定すると、`-c`および`-t`が無視されます。`-x`と同時に指定できません。

#### `-t`, `--time-header`
  出力フォーマットがNicoJKの時、一行目に時刻ヘッダとして
```
<!-- Fetched logfile from 2013-01-01T00:00:00+09:00 -->
```
  等と追加します。出力される時刻は、取得できたコメントの一番初めのコメントの時刻です。  
  NicoJKフォーマット以外の場合は無視されます。

#### `-b path`, `--base-path path`
  出力先のフォルダを指定します。このオプションを指定しない場合、カレントディレクトリに出力されます。

#### `-d`, `--directory`
  チャンネルと同じ名前のフォルダの中にファイルを出力します。フォルダが存在しない場合作成します。

#### `-c`, `--check-file`
  取得時間範囲がよく似たファイルが存在するかチェックします。存在した場合ダウンロード処理を行いません。判定の詳細は`-a`オプションの説明をご覧下さい。  
  `-f`の`[filename]`が省略され、かつ`-d`が指定されており、`-x`または`-j`が指定されていない場合のみ有効になります。

#### `-a`, `--check-range sec`
  取得時間範囲のはじめから前後指定秒内のコメントから始まり、かつ取得時間範囲のおわりから前後指定秒内のコメントで終わるファイルをよく似たファイルと判定するようにします。  
  省略した場合`60`となります。  
  コメントファイルのはじめの時間はファイル名から取得し、おわりの時間は最終行のコメントから取得します。  
  ファイル名の時間は全てUnix時として扱います。

##### 簡単な図解
```
→→→→→→→→→→→→→→→→→→→→→→→時間の流れ→→→→→→→→→→→→→→→→→→→→→→→
    ↓取得時間範囲のはじめ                                                  取得時間範囲のおわり↓
    ├─────────────────────────────────────────────┤    ：取得時間範囲
┌─┴─┐                                                                                  ┌─┴─┐：前後それぞれ指定秒だけ幅ができる
       ├───────────────────────────────────────────┤     ：このようなコメントファイルがあればダウンロードしない
          ├───────────────────────────────────────────┤  ：このようなコメントファイルがあってもダウンロードする
```

#### `-r num`, `--retry num`
  エラーが発生した際に再取得しに行く最大回数。サーバーに負荷をかけない程度にしましょう。  
  オプション自体を省略した場合、`3`となり、始めの1回目+再取得3回で最大4回取得に行きます。

#### `-i cookie`, `--cookie`
  Cookieとして利用する文字列を与えます。

#### `-h`, `--help`
  ヘルプを出力します。


### あまりやる気のない例
```
ruby *******.rb jk1 20130101000000 20130101010000 > out.txt
```
2013年01月01日午前00時00分00秒から2013年01月01日午前01時00分00秒までのjk1のコメントをダウンロードして out.txt に出力。

```
ruby *******.rb jk9 20130714222630 20130714223000 -f
```
2013年07月14日午後10時26分30秒から2013年07月14日午後10時30分00秒までのjk9のコメントをダウンロードして 1373808390.txt（一番始めのコメントのUnix時）に出力。
てーきゅー（TOKYO MX）のコメントが取得できるはずです

```
ruby *******.rb jk9 20130714222700 20130714223000 -f -s 30
```
上と全く同じコメントをダウンロードします。-m, -s, -eは主にスクリプトやバッチでの利用を想定しています。

```
ruby *******.rb jk9 20130714222700 20130714223000 -f -s 30 -d
```
上と全く同じコメントをダウンロードしますが、 jk9/1373808390.txt に出力されます。

```
ruby *******.rb jk9 20130714222700 20130714223000 -f -s 30 -d -b comm
```
上と全く同じコメントをダウンロードしますが、 comm/jk9/1373808390.txt に出力されます。ただし、commフォルダが存在しない場合失敗します。
-d, -bも主にスクリプトやバッチでの利用を想定しています。

## 開発者の方へ
標準出力には、-fオプションが設定されていない場合はフォーマットされたコメントのみが出力され、設定されている場合は一切出力されません。
これについてはできるだけ変更しないように努めます。

標準エラー出力に出力される内容は将来変更されます。

## D&D.jsについて
同じような環境で使っている人に対して車輪の再発明をさせないために公開したものであり、万人の環境で動かすことを想定していないことをご了承下さい。

## 更新履歴
### Ver.1.7.2 / 2013/11/17
- chatタグの属性の順番が生のXMLと同じになるように変更（>>887氏）
- 「"」「'」がそれぞれ「&quot;」「&apos;」に置き換わらないように修正（>>887氏）
- NicoJKフォーマットの場合、一行目にヘッダを入れるオプションを追加（>>887氏）

### Ver.1.7.1 / 2013/11/13
- REXMLの設定を利用して、ワークアラウンド的な処理を削除

### Ver.1.7 / 2013/11/12
- JikkyoRec形式でも出力できるようにした

### Ver.1.6 / 2013/11/10
- XML形式でも出力できるようにした
- 軽微なバグ修正

### Ver.1.5 / 2013/08/06
- Cookieを引数から与えられるようにした

### Ver.1.4 / 2013/07/24
- スクリプトに名前をつけた
- 同じような時間帯のコメントをダウンロードしないようにするオプションを追加

### Ver.1.3 / 2013/07/20
- ある程度の異常はめげずにリトライするようにした
- リトライしても上手くいかなかったら諦めて落ちるようにした

### Ver.1.2 / 2013/07/19
- オプションのパースにGetoptLongを利用するようにした
- 色々とオプションを追加
- ライセンス文章を追加して、無保証性を強調した

### Ver.1.1 / 2013/07/18
- Windowsでちゃんと動くように修正
- -f オプションを追加してファイル名の変更の手間を省けるようにした
- その他マイナーなバグの修正
