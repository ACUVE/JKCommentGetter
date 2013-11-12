# encoding: UTF-8
# JKCommentGetter Ver.1.7.1

# License: GPLv3 or later
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    Please see <http://www.gnu.org/licenses/>.

# ※予め設定が必要です
# 　Cookieの取得方法が人それぞれのため、getCookieメソッドを自前で実装する必要性があります。
#
# ■これはなに？
# 　ニコニコ実況のコメントをダウンロードするスクリプトです。
#
# ■コマンド
# 　ruby *******.rb チャンネル 取得時間範囲のはじめ 取得時間範囲のおわり [option....]
# 　　必須引数：
# 　　　チャンネル："jk1"など
# 　　　取得時間範囲のはじめ：Unix時または、YYYYMMDDhhmmss形式でも受け付けます。具体的には14桁でない時はUnix時として扱います。
# 　　　取得時間範囲のおわり：上に同じ。
# 　　オプション：
# 　　　-m sec, --margin sec
# 　　　　取得時間範囲の前後を指定秒だけ広げます。負の値も受け付けます。
# 　　　-s sec, --start-margin sec
# 　　　　取得時間範囲のはじめを指定秒だけ早くします。 -m による指定よりも優先されます。負の値も受け付けます。
# 　　　-e sec, --end-margin sec
# 　　　　取得時間範囲のおわりを指定秒だけ遅くします。 -m による指定よりも優先されます。負の値も受け付けます。
# 　　　-f [filename], --file [filename]
# 　　　　取得結果を filename に出力します。filenameを省略した場合、「(一番始めのコメントのUnix時).(フォーマット固有の拡張子)」に出力されます。
# 　　　　オプション自体を省略した場合、標準出力に出力します。
# 　　　-x, --xml
# 　　　　出力フォーマットをXMLにします。chatタグ以外の情報は失われています。
# 　　　　このオプションを指定すると、 -c が無視されます。 -j と同時に指定できません。
# 　　　-j, --jkl
# 　　　　出力フォーマットをJikkyoRec互換っぽくします。chatタグ以外の情報は失われています。
# 　　　　このオプションを指定すると、 -c が無視されます。 -x と同時に指定できません。
# 　　　-b path, --base-path path
# 　　　　出力先のフォルダを指定します。このオプションを指定しない場合、カレントディレクトリに出力されます。
# 　　　-d, --directory
# 　　　　チャンネルと同じ名前のフォルダの中にファイルを出力します。フォルダが存在しない場合作成します。
# 　　　-c, --check-file
# 　　　　取得時間範囲がよく似たファイルが存在するかチェックします。存在した場合ダウンロード処理を行いません。判定の詳細は -a オプションの説明をご覧下さい。
# 　　　　-f の [filename] が省略され、かつ -d が指定されており、 -x または -j が指定されていない場合のみ有効になります。
# 　　　-a, --check-range sec
# 　　　　取得時間範囲のはじめから前後指定秒内のコメントから始まり、かつ取得時間範囲のおわりから前後指定秒内のコメントで終わるファイルをよく似たファイルと判定するようにします。
# 　　　　省略した場合 60 となります。
# 　　　　コメントファイルのはじめの時間はファイル名から取得し、おわりの時間は最終行のコメントから取得します。
# 　　　　ファイル名の時間は全てUnix時として扱います。
# 　　　　　・簡単な図解
# 　　　　　　  →→→→→→→→→→→→→→→→→→→→→→→時間の流れ→→→→→→→→→→→→→→→→→→→→→→→
# 　　　　　　      ↓取得時間範囲のはじめ                                                  取得時間範囲のおわり↓
# 　　　　　　      ├─────────────────────────────────────────────┤    ：取得時間範囲
# 　　　　　　  ┌─┴─┐                                                                                  ┌─┴─┐：前後それぞれ指定秒だけ幅ができる
# 　　　　　　         ├───────────────────────────────────────────┤     ：このようなコメントファイルがあればダウンロードしない
# 　　　　　　            ├───────────────────────────────────────────┤  ：このようなコメントファイルがあってもダウンロードする
# 　　　-r num, --retry num
# 　　　　エラーが発生した際に再取得しに行く最大回数。サーバーに負荷をかけない程度にしましょう。
# 　　　　オプション自体を省略した場合、 3 となり、始めの1回目+再取得3回で最大4回取得に行きます。
# 　　　-i cookie, --cookie
# 　　　　Cookieとして利用する文字列を与えます。
# 　　　-h, --help
# 　　　　ヘルプを出力します。
#
# 　・あまりやる気のない例
# 　　ruby *******.rb jk1 20130101000000 20130101010000 > out.txt
# 　　　2013年01月01日午前00時00分00秒から2013年01月01日午前01時00分00秒までのjk1のコメントをダウンロードして out.txt に出力。
# 　　ruby *******.rb jk9 20130714222630 20130714223000 -f
# 　　　2013年07月14日午後10時26分30秒から2013年07月14日午後10時30分00秒までのjk9のコメントをダウンロードして 1373808390.txt（一番始めのコメントのUnix時）に出力。
# 　　　てーきゅー（TOKYO MX）のコメントが取得できるはずです
# 　　ruby *******.rb jk9 20130714222700 20130714223000 -f -s 30
# 　　　上と全く同じコメントをダウンロードします。-m, -s, -eは主にスクリプトやバッチでの利用を想定しています。
# 　　ruby *******.rb jk9 20130714222700 20130714223000 -f -s 30 -d
# 　　　上と全く同じコメントをダウンロードしますが、 jk9/1373808390.txt に出力されます。
# 　　ruby *******.rb jk9 20130714222700 20130714223000 -f -s 30 -d -b comm
# 　　　上と全く同じコメントをダウンロードしますが、 comm/jk9/1373808390.txt に出力されます。ただし、commフォルダが存在しない場合失敗します。
# 　　　-d, -bも主にスクリプトやバッチでの利用を想定しています。
#
# ■更新履歴
# 　○Ver.1.1 / 2013/07/18
# 　　・Windowsでちゃんと動くように修正
# 　　・-f オプションを追加してファイル名の変更の手間を省けるようにした
# 　　・その他マイナーなバグの修正
# 　○Ver.1.2 / 2013/07/19
# 　　・オプションのパースにGetoptLongを利用するようにした
# 　　・色々とオプションを追加
# 　　・ライセンス文章を追加して、無保証性を強調した
# 　○Ver.1.3 / 2013/07/20
# 　　・ある程度の異常はめげずにリトライするようにした
# 　　・リトライしても上手くいかなかったら諦めて落ちるようにした
# 　○Ver.1.4 / 2013/07/24
# 　　・スクリプトに名前をつけた
# 　　・同じような時間帯のコメントをダウンロードしないようにするオプションを追加
# 　○Ver.1.5 / 2013/08/06
# 　　・Cookieを引数から与えられるようにした
# 　○Ver.1.6 / 2013/11/10
# 　　・XML形式でも出力できるようにした
# 　　・軽微なバグ修正
# 　○Ver.1.7 / 2013/11/12
# 　　・JikkyoRec形式でも出力できるようにした
# 　○Ver.1.7.1 / 2013/11/13
# 　　・REXMLの設定を利用して、ワークアラウンド的な処理を削除

require 'net/http'
require 'rexml/document'
require 'getoptlong'

def getCookie
	# 引数でCookieが与えられなかった場合に呼ばれます。スクリプトの引数として与える場合は設定は不要です
	
	# 設定がよくわからなかったらニコニコ動画にログインして http://jk.nicovideo.jp/ を開いて、
	#       javascript:window.prompt("Cookie","'"+document.cookie+"'")
	# をアドレス欄に入力してEnter押して、表示されたプロンプトの中身をコピーしてすぐ下の行に貼り付けて、改行があるならば消して一行にまとめれば動くと思います。
	
	# ファイルパス中の \ は \\ とする必要性があります。
	# GoogleChrome用
	# `sqlite3.exe "{ここをプロファイルフォルダの場所に修正}\\Cookies" -separator = "select name,value from cookies where (host_key='.nicovideo.jp' or host_key='jk.nicovideo.jp' or host_key='.jk.nicovideo.jp') and path='/' and not secure and name='user_session'"`
	#   特殊な設定をしていなければ、クッキーへのパスは C:\\Users\\{ユーザー名}\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Cookies となると思います。
	# Firefox用
	# `sqlite3.exe "{ここをプロファイルフォルダの場所に修正}\\cookies.sqlite" -separator = "select name,value from moz_cookies where (host='.nicovideo.jp' or host='jk.nicovideo.jp' or host='.jk.nicovideo.jp') and path='/' and not isSecure and name='user_session'"`
	
	# ***** Could not extract comments form comment XML. という例外が必ずと言っていい程発生する場合はCookieが正しくない可能性が高いです。 *****
end

def logging(*str)
	$stderr.print 'log: ', *str
end

class CommentGetter
	JkServer = 'jk.nicovideo.jp'
	private_constant :JkServer
	
public
	# jknum: 'jk1'など
	# cookie: クッキー美味しい
	def initialize(jknum, cookie, retrynum)
		@jknum = jknum
		@cookie = cookie
		@retrynum = retrynum
	end
	
	# start_time: 取得範囲のはじめ、Unix時またはTimeクラス
	# end_time: 取得範囲のおわり、Unix時またはTimeクラス
	def getChatElementsRange(start_time, end_time)
		carr = []
		crr_time = end_time
		while 1
			break if start_time.to_i > crr_time.to_i
			for i in 0..@retrynum
				if i != 0
					logging 'flv情報が取得出来なかったため再取得します', ?\n
					sleep 1
				end
				
				flv = getFlvInfo(crr_time, crr_time)
				break if flv
			end
			raise RuntimeError, 'Could not get flv information.' if flv == nil
			
			logging 'スレッド', flv['thread_id'], 'から読み込み開始: start_time=', Time.at(flv['start_time'].to_i), ', end_time=', Time.at(flv['end_time'].to_i), ?\n
			arr = getThreadComment(start_time, end_time, flv['ms'], flv['http_port'], flv['thread_id'], flv['user_id'])
			raise RuntimeError, 'Could not get thread comments.' if arr == nil
			logging 'スレッド', flv['thread_id'], 'から読み取り完了: size=', arr.size, ?\n
			
			carr = arr + carr
			crr_time = flv['start_time'].to_i - 1
		end
		carr
	end
	
private
	# 特定Threadのコメントを取得
	# start_time: 取得範囲のはじめ、Unix時またはTimeクラス
	# end_time: 取得範囲のおわり、Unix時またはTimeクラス
	# ms: メッセージサーバーのIP or ドメイン
	# http_port: HTMLで得られるポート番号
	# thread_id: スレッドID
	# user_id: ユーザーID
	def getThreadComment(start_time, end_time, ms, http_port, thread_id, user_id)
		carr = []
		crr_time = end_time
		while 1
			break if start_time.to_i > crr_time.to_i
			
			for j in 0..@retrynum
				if j != 0
					logging 'コメントXMLからコメントが抽出出来なかったため再取得します', ?\n
					sleep 1
				end
				
				for i in 0..@retrynum
					if i != 0
						logging 'コメントXMLが取得出来なかったため再取得します', ?\n
						sleep 1
					end
					
					xml = getCommentXML(ms, http_port, thread_id, -1000, crr_time, user_id)
					break if xml
				end
				raise RuntimeError, 'Could not get comment XML.' if xml == nil
				
				arr = getChatElementsFromXML(xml)
				break if arr
			end
			raise RuntimeError, 'Could not extract comments form comment XML.' if arr == nil
			
			if carr.first
				first_no = carr.first.attribute('no').to_s.to_i
				index = arr.rindex{|chat| chat.attribute('no').to_s.to_i < first_no}
				break if index == nil
				addarr = arr[0..index]
			else
				addarr = arr
			end
			carr = addarr + carr
			logging 'スレッド', thread_id, 'から', carr.size, 'コメント読み込んだ: ', Time.at(carr.first.attribute('date').to_s.to_i), ?\n
			break if arr.size < 1000
			crr_time = carr.first.attribute('date').to_s.to_i	# 1秒間に1000コメント以上されている場合に無限ループする
																# そのような場合はres_fromを指定すべきなのであろうが、まずありえないの実装しない
			sleep 1
		end
		index = carr.index{|chat| chat.attribute('date').to_s.to_i >= start_time.to_i}
		if index then carr[index...carr.size] else [] end
	end
	# start_time, end_time: Unix時のIntでもよし、Timeクラスでもよし
	def getFlvInfo(start_time, end_time)
		Net::HTTP.start(JkServer) do |http|
			req = Net::HTTP::Get.new("/api/v2/getflv?v=#{@jknum}&start_time=#{start_time.to_i}&end_time=#{end_time.to_i}")
			req.add_field('Cookie', @cookie)
			res = http.request(req)
			return nil if res.code != '200'
			flv = htmlform2hash(res.body.force_encoding('UTF-8'))
			return nil if flv['error']
			flv
		end
	end
	# thread_id: スレッドID
	def getWaybackkey(thread_id)
		Net::HTTP.start(JkServer) do |http|
			req = Net::HTTP::Get.new("/api/v2/getwaybackkey?thread=#{thread_id}")
			req.add_field('Cookie', @cookie)
			res = http.request(req)
			return nil if res.code != '200'
			key = htmlform2hash(res.body.force_encoding('UTF-8'))
			return nil if key['error_code']
			key['waybackkey']
		end
	end
	# ms: メッセージサーバーのIP or ドメイン
	# http_port: HTMLで得られるポート番号
	# thread_id: スレッドID
	# res_from: このレス番号以降を得る、負の値を指定するとwhen以前のその数のコメントが得られる（ただし最大-1000まで）
	# time_when: この時間より前が得られる Unix時でもTimeクラスでもよし
	# user_id: ユーザーID
	def getCommentXML(ms, http_port, thread_id, res_from, time_when, user_id)
		waybackkey = getWaybackkey(thread_id)
		return nil if waybackkey == nil
		Net::HTTP.start(ms, http_port) do |http|
			req = Net::HTTP::Get.new("/api/thread?thread=#{thread_id}&res_from=#{res_from}&version=20061206&when=#{time_when.to_i}&user_id=#{user_id}&waybackkey=#{waybackkey}")
			res = http.request(req)
			return nil if res.code != '200'
			res.body.force_encoding('UTF-8')
		end
	end
	def getChatElementsFromXML(xml)
		begin
			doc = REXML::Document.new(xml)
			doc.context[:attribute_quote] = :quote
		rescue
			return nil
		end
		return nil if doc.elements['packet/thread'].attribute('resultcode').to_s != '0'
		
		ret = []
		doc.elements.each('packet/chat') do |ele|
			c = ele.clone
			c.text = ele.text
			ret.push(c)
		end
		ret
	end
	def htmlform2hash(str)
		Hash[*str.split(?&).map{|v| v.split(?=, 2)}.map{|a, b| [a, URI.decode_www_form_component(b)]}.flatten(1)]
	end
end

def printChatArrayNicoJKFormat(io, arr)
	arr.each do |c|
		io.puts c.to_s.gsub(/[\r\n]/, {"\r" => '&#13;', "\n" => '&#10;'})
	end
end

def printChatArrayXML(io, arr)
	io.puts <<-'EOS'
<?xml version="1.0" encoding="UTF-8"?>
<packet>
	EOS
	
	arr.each do |c|
		io.print '  ', c.to_s, ?\n
	end
	
	io.puts '</packet>'
end

def printChatArrayJikkyoRec(io, arr)
	# ここでARGVを使うのは行儀がよくないかな
	io.puts %Q(<JikkyoRec startTime="#{getTimeFromARGV(ARGV[1]).to_i}000" channel="#{ARGV[0]}" />)
	io.puts
	
	arr.each do |c|
		io.puts c.to_s
	end
end

def getTimeFromARGV(str)
	return nil if !numonly?(str)
	if m = str.match(/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/)	# YYYYMMDDhhmmss チェック
		Time.local(m[1], m[2], m[3], m[4], m[5], m[6])
	else
		Time.at(str.to_i)
	end
end

def numonly?(str)
	str.match(/^\d+$/) != nil
end
def pmnumonly?(str)
	str.match(/^[+-]?\d+$/) != nil
end

def errorexit(str)
	$stderr.puts "** #{str} **"
	$stderr.puts
	showhelp($stderr)
	exit -1
end

def showhelp(io = $stdout)
	io.puts "Usage: ruby #{$0} チャンネル 取得時間範囲のはじめ 取得時間範囲のおわり [option...]"
	io.puts 'Options:'
	io.puts '  -m sec  --margin sec                取得時間範囲の前後を指定秒だけ広げます'
	io.puts '  -s sec  --start-margin sec          取得時間範囲のはじめを指定秒だけ早くします'
	io.puts '  -e sec  --end-margin sec            取得時間範囲のおわりを指定秒だけ遅くします'
	io.puts '  -f [filename]  --file [filename]    出力するファイル名を指定します'
	io.puts '  -x  --xml                           出力フォーマットをXMLにします'
	io.puts '  -j  --jkl                           出力フォーマットをJikkyoRec互換っぽくします'
	io.puts '  -b path  --base-path path           ファイル出力のフォルダを指定します'
	io.puts '  -d  --directory                     チャンネルと同じ名前のフォルダの中にファイルを出力します'
	io.puts '  -c  --check-file                    取得時間範囲がよく似たファイルが存在する場合ダウンロードしなくなります'
	io.puts '  -a sec  --check-range sec           よく似たファイルと判定する時間範囲を設定します'
	io.puts '  -r num  --retry num                 取得エラーが発生した際に再取得へ行く回数'
	io.puts '  -i cookie  --cookie cookie          Cookieとして利用する文字列を与えます'
	io.puts '  -h  --help                          このヘルプを表示し終了します'
	io.puts
	io.puts '    詳細はソースコードをご覧ください'
end


# オプションのパース
opt = GetoptLong.new
opt.set_options(
	['-m',	'--margin',			GetoptLong::REQUIRED_ARGUMENT],
	['-s',	'--start-margin',	GetoptLong::REQUIRED_ARGUMENT],
	['-e',	'--end-margin',		GetoptLong::REQUIRED_ARGUMENT],
	['-f',	'--file',			GetoptLong::OPTIONAL_ARGUMENT],
	['-x',	'--xml',			GetoptLong::NO_ARGUMENT],
	['-j',	'--jkl',			GetoptLong::NO_ARGUMENT],
	['-b',	'--base-path',		GetoptLong::REQUIRED_ARGUMENT],
	['-d',	'--directory',		GetoptLong::NO_ARGUMENT],
	['-c',	'--check-file',		GetoptLong::NO_ARGUMENT],
	['-a',	'--check-range',	GetoptLong::REQUIRED_ARGUMENT],
	['-r',	'--retry',			GetoptLong::REQUIRED_ARGUMENT],
	['-i',	'--cookie',			GetoptLong::REQUIRED_ARGUMENT],
	['-h',	'--help',			GetoptLong::NO_ARGUMENT]
)

OPT = {}
opt.each{|n, a| OPT[n[1].to_sym] = a}
if OPT[:h] then showhelp; exit 0 end
errorexit('引数が足りません') if ARGV.size < 3
errorexit('--marginオプションがおかしいです') if OPT[:m] && !pmnumonly?(OPT[:m])
errorexit('--start-marginオプションがおかしいです') if OPT[:s] && !pmnumonly?(OPT[:s])
errorexit('--end-marginオプションがおかしいです') if OPT[:e] && !pmnumonly?(OPT[:e])
errorexit('--retryオプションがおかしいです') if OPT[:r] && !numonly?(OPT[:r])
errorexit('--check-rangeオプションがおかしいです') if OPT[:a] && !numonly?(OPT[:a])
errorexit('--xmlオプションと--jklオプションは同時に指定できません') if OPT[:x] && OPT[:j]

# クッキーが設定されているかテスト
cookie = OPT[:i] || getCookie
errorexit('Cookieが設定されていません 設定を行なってください') if cookie == nil || cookie.strip == ''
cookie = cookie.strip

jknum = ARGV[0]
start_time = getTimeFromARGV(ARGV[1])
end_time = getTimeFromARGV(ARGV[2])
errorexit('取得時間範囲のはじめがおかしいです') if start_time == nil
errorexit('取得時間範囲のおわりがおかしいです') if end_time == nil

start_time -= if OPT[:s] then OPT[:s].to_i elsif OPT[:m] then OPT[:m].to_i else 0 end
end_time += if OPT[:e] then OPT[:e].to_i elsif OPT[:m] then OPT[:m].to_i else 0 end
retrynum = if OPT[:r] then OPT[:r].to_i else 3 end
check_range = if OPT[:a] then OPT[:a].to_i else 60 end

errorexit('取得時間範囲が存在しません') if start_time > end_time

base_path = File.expand_path(OPT[:b] || '') + ?/
errorexit('--base-pathのディレクトリが存在しません') if !Dir.exist?(base_path)

# よく似た時間のコメントファイルが存在しないかのチェック
if OPT[:c] && (OPT[:f] && OPT[:f].empty?) && OPT[:d] && !(OPT[:x] || OPT[:j])
	dirpath = base_path + jknum + ?/
	Dir.exist?(dirpath) && Dir.glob(dirpath + ?*).each do |file|
		if File.exist?(file) && (m = File.basename(file).match(/^\d+/)) && (m[0].to_i - start_time.to_i).abs <= check_range
			File.open(file) do |file|
				ll = file.readlines.last
				if (m = ll.force_encoding('UTF-8').match(/^<chat[^>]+date="(\d+)"[^>]*>.*<\/chat>/)) && (m[1].to_i - end_time.to_i).abs <= check_range
					logging 'ダウンロードしようとしている取得時間範囲によく似た時間帯のコメントファイルが存在するためダウンロードを行いません。', ?\n
					exit 0
				end
			end
			logging file, ?\n
		end
	end
end

logging jknum, ' を ', start_time, ' から ', end_time, 'まで取得します', ?\n
# コメント取得処理
cm = CommentGetter.new(jknum, cookie, retrynum)
chat = cm.getChatElementsRange(start_time, end_time)

if chat.empty?	# 一つもコメントが得られなかった
	$stderr.puts 'コメントが一つも得られませんでした。エラーだと考えられます。'
	exit 1
end

outfile = $stdout
fileopen = false
if OPT[:f]
	filename = if OPT[:f].empty? then "#{chat.first.attribute('date').to_s}.#{if OPT[:x] then 'xml' elsif OPT[:j] then 'jkl' else 'txt' end}" else OPT[:f] end
	if OPT[:d]
		dirpath = base_path + jknum + ?/
		if !Dir.exist?(dirpath)
			begin
				Dir.mkdir(dirpath)
				fullpath = dirpath + filename
			rescue
				logging 'フォルダの作成に失敗しました', ?\n
				fullpath = base_path + filename
			end
		else
			fullpath = dirpath + filename
		end
	else
		fullpath = base_path + filename
	end
	logging fullpath, ' へ出力します', ?\n
	outfile = File.open(fullpath, 'w')
	fileopen = true
end

if OPT[:x]
	printChatArrayXML(outfile, chat)
elsif OPT[:j]
	printChatArrayJikkyoRec(outfile, chat)
else
	printChatArrayNicoJKFormat(outfile, chat)
end

if fileopen
	outfile.close
end
