# encoding: UTF-8
# License: GPLv3
# Ver.1.1

# ※予め設定が必要です
# 　Cookieの取得方法が人それぞれのため、getCookieメソッドを自前で実装する必要性があります。
#
# ■これはなに？
# 　ニコニコ実況のコメントをダウンロードするスクリプトです。
#
# ■コマンド
# 　ruby *******.rb チャンネル 取得時間範囲のはじめ 取得時間範囲のおわり [ext.]
# 　　チャンネル："jk1"など
# 　　取得時間範囲のはじめ：Unix時または、YYYYMMDDhhmmss形式でも受け付けます。具体的には14桁でない時はUnix時として扱います
# 　　取得時間範囲のおわり：上に同じ
# 　　ext.： 第4引数を -f にするとファイルに出力します。ファイル名は「(一番始めのコメントのUnix時).txt」です。
#
# 　・例
# 　　ruby *******.rb jk1 20130101000000 20130101010000 > out.txt
# 　　　2013年01月01日午前00時00分00秒から2013年01月01日午前01時00分00秒までのjk1のコメントをダウンロードして out.txt に出力
# 　　ruby *******.rb jk9 20130714222630 20130714223000 -f
# 　　　2013年07月14日午後10時26分30秒から2013年07月14日午後10時30分00秒までのjk9のコメントをダウンロードして 1373808390.txt（一番始めのコメントのUnix時）に出力
# 　　　てーきゅー（TOKYO MX）の時間帯のはずです

# ■更新履歴
# 　○Ver.1.1 / 2013/07/18
# 　　・Windowsでちゃんと動くように修正
# 　　・-f オプションを追加してファイル名の変更の手間を省けるようにした
# 　　・その他マイナーなバグの修正


require 'net/http'
require 'rexml/document'

def getCookie
	# 設定がよくわからなかったらニコニコ動画にログインして http://jk.nicovideo.jp/ を開いて、
	#       javascript:window.prompt("Cookie","'"+document.cookie+"'")
	# をアドレス欄に入力してEnter押して、表示されたプロンプトの中身をコピーしてすぐ下の行に貼り付けて、改行があるならば消して一行にまとめれば動くと思います。
	
	# 以下のコードはGoogleChrome用のみVer28にて動作確認済み。
	# ファイルパス中の \ は \\ とする必要性があります。
	# GoogleChrome用
	# `sqlite3.exe "{ここをプロファイルフォルダの場所に修正}\\Cookies" -separator = "select name,value from cookies where (host_key='.nicovideo.jp' or host_key='jk.nicovideo.jp' or host_key='.jk.nicovideo.jp') and path='/' and not secure and name='user_session'"`
	#   特殊な設定をしていなければ、クッキーへのパスは C:\\Users\\{ユーザー名}\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Cookies となると思います。
	# Firefox用
	# `sqlite3.exe "{ここをプロファイルフォルダの場所に修正}\\cookies.sqlite" -separator = "select name,value from moz_cookies where (host='.nicovideo.jp' or host='jk.nicovideo.jp' or host='.jk.nicovideo.jp') and path='/' and not isSecure and name='user_session'"`
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
	def initialize(jknum, cookie)
		@jknum = jknum
		@cookie = cookie
	end
	
	# start_time: 取得範囲のはじめ、Unix時またはTimeクラス
	# end_time: 取得範囲のおわり、Unix時またはTimeクラス
	def getChatElementsRange(start_time, end_time)
		carr = []
		crr_time = end_time
		while 1
			break if start_time.to_i > crr_time.to_i
			flv = getFlvInfo(crr_time, crr_time)
			break if flv == nil	# ここでbreakする時は異常
			logging 'スレッド', flv['thread_id'], 'から読み込み開始: start_time=', Time.at(flv['start_time'].to_i), ', end_time=', Time.at(flv['end_time'].to_i), ?\n
			arr = getThreadComment(start_time, end_time, flv['ms'], flv['http_port'], flv['thread_id'], flv['user_id'])
			break if arr == nil	# ここでbreakする時は異常
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
			xml = getCommentXML(ms, http_port, thread_id, -1000, crr_time, user_id)
			break if xml == nil	# ここでbreakする時は異常
			arr = getChatElementsFromXML(xml)
			break if arr == nil	# ここでbreakする時は異常
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
		doc = REXML::Document.new(xml)
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
		line = c.to_s.gsub(/[\r\n]/, {"\r" => '&#13;', "\n" => '&#10;'})
		if m = line.match(/^(<chat[^>]+>)(.*<\/chat>)/)
			line = m[1].gsub(/'/, ?") + m[2]
		end
		io.puts line
	end
end

def getTimeFromARGV(str)
	return nil if str.match(/^\d+$/) == nil
	if m = str.match(/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/)	# YYYYMMDDhhmmss チェック
		Time.local(m[1], m[2], m[3], m[4], m[5], m[6])
	else
		Time.at(str.to_i)
	end
end

exit -1 if ARGV.size < 3

jknum = ARGV[0]
start_time = getTimeFromARGV(ARGV[1])
end_time = getTimeFromARGV(ARGV[2])

exit -1 if start_time == nil || end_time == nil

cookie = getCookie

if cookie == nil || cookie == ''
	$stderr.puts 'Cookieが設定されていません。設定を行なってください。'
	exit -1
end

cookie.strip!
cm = CommentGetter.new(jknum, cookie)
chat = cm.getChatElementsRange(start_time, end_time)

exit 0 if chat.empty?	# 何も無いときは出力無く死ぬ

outfile = $stdout
fileopen = false
if ARGV.size >= 4 && ARGV[3] == '-f'
	outfile = File.open("#{chat.first.attribute('date').to_s}.txt", 'w')
	fileopen = true
end

printChatArrayNicoJKFormat(outfile, chat)

if fileopen
	outfile.close
end