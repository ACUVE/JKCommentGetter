# encoding: UTF-8
# JKCommentGetter Ver.1.7.2

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
	def initialize(jknum, cookie, retrynum, args = {})
		@jknum = jknum
		@cookie = cookie
		@retrynum = retrynum
		@logging = args[:logging]
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
			if flv['error']
				logging __method__.to_s, ' error! error=', flv['error'], ?\n
				return nil
			end
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
	def logging(*str)
		@logging.call(*str) if @logging
	end
end

# pasted from rexml/formatters/default.rb
class ChatFormatter < REXML::Formatters::Default
	FrontAttributes = %w(thread no vpos date mail yourpost user_id premium anonymity)
	
	def write_element(node, output)
		output << "<#{node.expanded_name}"
		
		node.attributes.to_a.map{|a|
			Hash === a ? a.values : a
		}.flatten.sort_by{|attr| "%02d#{attr.name}" % (FrontAttributes.index(attr.name) || 99)}.each do |attr|
			output << " "
			attr.write(output)
		end unless node.attributes.empty?
		
		if node.children.empty?
			output << " " if @ie_hack
			output << "/"
		else
			output << ">"
			node.children.each{|child|
				write(child, s = "")
				output << s
			}
			output << "</#{node.expanded_name}"
		end
		output << ">"
	end
	
	def write_text(node, output)
		output << node.to_s.gsub(/&apos;|&quot;/, {"&apos;" => "'", "&quot;" => '"'})
	end
end

def printChatArrayNicoJKFormat(io, arr)
	if OPT[:t] && !arr.empty?
		ts = Time.at(arr.first.attribute('date').to_s.to_i).strftime('%FT%T%z'); ts[ts.size-2, 0] = ?:
		io.puts "<!-- Fetched logfile from #{ts} -->"
	end
	
	f = ChatFormatter.new
	arr.each do |c|
		f.write(c, s = '')
		io.puts s.gsub(/[\r\n]/, {"\r" => '&#13;', "\n" => '&#10;'})
	end
end

def printChatArrayXML(io, arr)
	io.puts <<-'EOS'
<?xml version="1.0" encoding="UTF-8"?>
<packet>
	EOS
	
	f = ChatFormatter.new
	arr.each do |c|
		f.write(c, s = '')
		io.print '  ', s, ?\n
	end
	
	io.puts '</packet>'
end

def printChatArrayJikkyoRec(io, arr)
	io.puts %Q(<JikkyoRec startTime="#{getTimeFromARGV(ARGV[1]).to_i}000" channel="#{ARGV[0]}" />)
	io.puts
	
	f = ChatFormatter.new
	arr.each do |c|
		f.write(c, s = '')
		io.puts s
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
	io.puts <<-EOS
Usage: ruby #{$0} チャンネル 取得時間範囲のはじめ 取得時間範囲のおわり [option...]
Options:
  -m sec  --margin sec                取得時間範囲の前後を指定秒だけ広げます
  -s sec  --start-margin sec          取得時間範囲のはじめを指定秒だけ早くします
  -e sec  --end-margin sec            取得時間範囲のおわりを指定秒だけ遅くします
  -f [filename]  --file [filename]    出力するファイル名を指定します
  -x  --xml                           出力フォーマットをXMLにします
  -j  --jkl                           出力フォーマットをJikkyoRec互換っぽくします
  -t  --time-header                   NicoJKフォーマットの一番初めに時刻ヘッダを追加します
  -b path  --base-path path           ファイル出力のフォルダを指定します
  -d  --directory                     チャンネルと同じ名前のフォルダの中にファイルを出力します
  -c  --check-file                    取得時間範囲がよく似たファイルが存在する場合ダウンロードしなくなります
  -a sec  --check-range sec           よく似たファイルと判定する時間範囲を設定します
  -r num  --retry num                 取得エラーが発生した際に再取得へ行く回数
  -i cookie  --cookie cookie          Cookieとして利用する文字列を与えます
  -h  --help                          このヘルプを表示し終了します

    詳細は README.txt をご覧ください
	EOS
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
	['-t',	'--time-header',	GetoptLong::NO_ARGUMENT],
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
cm = CommentGetter.new(jknum, cookie, retrynum, logging: method(:logging))
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
