# JKCommentGetter Ver.1.9

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

require 'getoptlong'
require_relative 'JKComment'

include JKComment

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

def getTimeFromARGV(str)
	return nil if !numonly?(str)
	if m = str.match(/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/)	# YYYYMMDDhhmmss チェック
		Time.local(m[1], m[2], m[3], m[4], m[5], m[6])
	else
		Time.at(str.to_i)
	end
end

def getStartTimeAndEndTime
	start_time = getTimeFromARGV(ARGV[1]); end_time = getTimeFromARGV(ARGV[2])
	if start_time && !end_time && prelativetime?(ARGV[2])
		end_time = start_time + parse_prelativetime(ARGV[2])
	end
	[start_time, end_time]
end

def numonly?(str)
	str.match(/^\d+$/) != nil
end
def pmnumonly?(str)
	str.match(/^[+-]?\d+$/) != nil
end
def prelativetime?(str)
	str.match(/^\+?\d+[smhd]$/i) != nil
end
def parse_prelativetime(str)
	rel = str.to_i
	rel * {?s => 1, ?m => 60, ?h => 60 * 60, ?d => 60 * 60 * 24}[str[-1].downcase]
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
  -o comment  --comment commment      ファイルの頭の辺りに指定したコメントを追加します
  -b path  --base-path path           ファイル出力のフォルダを指定します
  -d  --directory                     チャンネルと同じ名前のフォルダの中にファイルを出力します
  -c  --check-file                    取得時間範囲がよく似たファイルが存在する場合ダウンロードしなくなります
  -a sec  --check-range sec           よく似たファイルと判定する時間範囲を設定します
  -r num  --retry num                 取得エラーが発生した際に再取得へ行く回数
  -i cookie  --cookie cookie          Cookieとして利用する文字列を与えます
  -p  --perfect                       完全なコメントが取得できたと保証できない時にエラーで落ちるようにします
  -w  --working-directory             カレントディレクトリをスクリプトがあるフォルダにします
  -h  --help                          このヘルプを表示し終了します

    詳細は README.md をご覧ください
	EOS
end


# オプションのパース
opt = GetoptLong.new
opt.set_options(
	# gklnqsuvwyz
	['-m',	'--margin',				GetoptLong::REQUIRED_ARGUMENT],
	['-s',	'--start-margin',		GetoptLong::REQUIRED_ARGUMENT],
	['-e',	'--end-margin',			GetoptLong::REQUIRED_ARGUMENT],
	['-f',	'--file',				GetoptLong::OPTIONAL_ARGUMENT],
	['-x',	'--xml',				GetoptLong::NO_ARGUMENT],
	['-j',	'--jkl',				GetoptLong::NO_ARGUMENT],
	['-t',	'--time-header',		GetoptLong::NO_ARGUMENT],
	['-o',	'--comment',			GetoptLong::REQUIRED_ARGUMENT],
	['-b',	'--base-path',			GetoptLong::REQUIRED_ARGUMENT],
	['-d',	'--directory',			GetoptLong::NO_ARGUMENT],
	['-c',	'--check-file',			GetoptLong::NO_ARGUMENT],
	['-a',	'--check-range',		GetoptLong::REQUIRED_ARGUMENT],
	['-r',	'--retry',				GetoptLong::REQUIRED_ARGUMENT],
	['-i',	'--cookie',				GetoptLong::REQUIRED_ARGUMENT],
	['-p',	'--perfect',			GetoptLong::NO_ARGUMENT],
	['-w',	'--working-directory',	GetoptLong::NO_ARGUMENT],
	['-h',	'--help',				GetoptLong::NO_ARGUMENT]
)

OPT = {}
opt.each{|n, a| OPT[n[1].to_sym] = a}
if OPT[:h] then showhelp; exit 0 end

Dir.chdir(File.dirname(__FILE__)) if OPT[:w]

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
start_time, end_time = getStartTimeAndEndTime
errorexit('取得時間範囲のはじめがおかしいです') if start_time == nil
errorexit('取得時間範囲のおわりがおかしいです') if end_time == nil

argv_start_time = start_time; argv_end_time = end_time
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
cm = CommentGetter.new(cookie, retrynum, logging: method(:logging))
chat = cm.getChatElementsRange(jknum, start_time, end_time, !!OPT[:p])

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

arg = {
	jknum: jknum,
	start_time: start_time,
	end_time: end_time,
	argv_start_time: argv_start_time,
	argv_end_time: argv_end_time,
	time_header: !!OPT[:t],
	comment: OPT[:o]
}

if OPT[:x]
	printChatArrayXML(outfile, chat, arg)
elsif OPT[:j]
	printChatArrayJikkyoRec(outfile, chat, arg)
else
	printChatArrayNicoJKFormat(outfile, chat, arg)
end

if fileopen
	outfile.close
end
