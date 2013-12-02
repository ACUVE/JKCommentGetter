# JKComment.rb

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

module JKComment
	# ニコニコ実況からコメントをダウンロードするクラス
	class CommentGetter
		JkServer = 'jk.nicovideo.jp'
		private_constant :JkServer
		
		attr_reader :state
		
		module Constants
			NOTWORKING = 0
			WORKING = 1
		end
		include Constants
		
	public
		# cookie: クッキー美味しい
		# retrynum: 処理を失敗した際にリトライする最大回数
		# args: その他の引数
		def initialize(cookie, retrynum = 3, args = {})
			@cookie = cookie
			@retrynum = retrynum
			@logging = args[:logging]
			
			@state = NOTWORKING
			@crr_time = nil
		end
		
		# 指定期間のコメントのChatElementsを取得する。時間によりソート済みである。
		# start_time: 取得範囲のはじめ、Unix時またはTimeクラス
		# end_time: 取得範囲のおわり、Unix時またはTimeクラス
		def getChatElementsRange(jknum, start_time, end_time)
			et = getChatElementsThreadRange(jknum, start_time, end_time)
			
			carr = []
			et.each do |obj|
				arr = obj[:chat]
				unless arr.empty?
					if carr.empty?
						carr.concat(arr)
					else
						firstdate = arr.first.attribute('date').to_s.to_i
						index = (carr.rindex{|o| o.attribute('date').to_s.to_i <= firstdate} || -1) + 1
						if index == carr.size
							carr.concat(arr)
						else
							lastdate = carr.last.attribute('date').to_s.to_i
							index2 = (arr.index{|o| lastdate <= o.attribute('date').to_s.to_i}) || arr.size
							s = arr.slice!(0...index2)
							c = carr.slice!(index...carr.size).concat(s).sort_by!{|c| [c.attribute('date').to_s.to_i, c.attribute('thread').to_s.to_i, c.attribute('no').to_s.to_i]}
							carr.concat(c).concat(arr)
						end
					end
				end
			end
			
			carr
		end
		
		# 指定期間のコメントのChatElementsとFlv情報をスレッドごとに取得する。
		# start_time: 取得範囲のはじめ、Unix時またはTimeクラス
		# end_time: 取得範囲のおわり、Unix時またはTimeクラス
		def getChatElementsThreadRange(jknum, start_time, end_time)
			raise RuntimeError, 'Already started.' if @state == WORKING
			
			@state = WORKING
			@crr_time = Time.at(end_time.to_i)
			begin
				carr = []
				crr_time = end_time
				while 1
					for i in 0..@retrynum
						if i != 0
							logging 'flv情報が取得出来なかったため再取得します', ?\n
							sleep 1
						end
						
						flv = getFlvInfo(jknum, crr_time, crr_time)
						
						break if flv
					end
					raise RuntimeError, 'Could not get flv information.' if flv == nil
					
					break if start_time.to_i > flv['end_time'].to_i
					
					logging 'スレッド', flv['thread_id'], 'から読み込み開始: start_time=', Time.at(flv['start_time'].to_i), ', end_time=', Time.at(flv['end_time'].to_i), ?\n
					arr = getThreadComment(start_time, end_time, flv['ms'], flv['http_port'], flv['thread_id'], flv['user_id'])
					raise RuntimeError, 'Could not get thread comments.' if arr == nil
					logging 'スレッド', flv['thread_id'], 'から読み取り完了: size=', arr.size, ?\n
					
					carr << {
						flv: flv,
						chat: arr
					} unless arr.empty?
					crr_time = flv['start_time'].to_i - 1
				end
			ensure
				@state = NOTWORKING
			end
			
			carr.reverse	# 時間的に後ろのものから取得しているので反転
		end
		
		# どこまで取得したかを返すメソッド
		def currentGetTime
			@crr_time
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
				if carr.first
					logging 'スレッド', thread_id, 'から', carr.size, 'コメント読み込んだ: ', Time.at(carr.first.attribute('date').to_s.to_i), ?\n
				else
					logging 'スレッド', thread_id, 'から0コメント読み込んだ', ?\n
				end
				break if arr.size < 1000
				crr_time = carr.first.attribute('date').to_s.to_i	# 1秒間に1000コメント以上されている場合に先のコメントが取得できない問題があるが気にしない
				@crr_time = Time.at(crr_time)
				sleep 1
			end
			index = carr.index{|chat| chat.attribute('date').to_s.to_i >= start_time.to_i}
			if index then carr[index...carr.size] else [] end
		end
		# start_time, end_time: Unix時のIntでもよし、Timeクラスでもよし
		def getFlvInfo(jknum, start_time, end_time)
			Net::HTTP.start(JkServer) do |http|
				req = Net::HTTP::Get.new("/api/v2/getflv?v=#{jknum}&start_time=#{start_time.to_i}&end_time=#{end_time.to_i}")
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

	def printChatArrayNicoJKFormat(io, arr, arg = {})
		if arg[:time_header] && !arr.empty?
			raise RuntimeError, 'Need arg[:start_time].' unless arg[:start_time]
			
			ts = Time.at(arg[:start_time].to_i).strftime('%FT%T%z'); ts[ts.size-2, 0] = ?:
			io.puts "<!-- Fetched logfile from #{ts} -->"
		end
		io.puts "<!-- #{arg[:comment].encode('UTF-8')} -->" if arg[:comment]
		
		f = ChatFormatter.new
		arr.each do |c|
			f.write(c, s = '')
			io.puts s.gsub(/[\r\n]/, {"\r" => '&#13;', "\n" => '&#10;'})
		end
	end
	module_function :printChatArrayNicoJKFormat
	
	def printChatArrayXML(io, arr, arg = {})
		io.puts %q(<?xml version="1.0" encoding="UTF-8"?>)
		io.puts "<!-- #{arg[:comment].encode('UTF-8')} -->" if arg[:comment]
		io.puts '<packet>'
		
		f = ChatFormatter.new
		arr.each do |c|
			f.write(c, s = '')
			io.print '  ', s, ?\n
		end
		
		io.puts '</packet>'
	end
	module_function :printChatArrayXML

	def printChatArrayJikkyoRec(io, arr, arg = {})
		raise RuntimeError, 'Need arg[:argv_start_time] and arg[:jknum].' unless arg[:argv_start_time] && arg[:jknum]
		
		io.puts %Q(<JikkyoRec startTime="#{arg[:argv_start_time].to_i}000" channel="#{arg[:jknum]}" />)
		io.puts "<!-- #{arg[:comment].encode('UTF-8')} -->" if arg[:comment]
		io.puts
		
		f = ChatFormatter.new
		arr.each do |c|
			f.write(c, s = '')
			io.puts s
		end
	end
	module_function :printChatArrayJikkyoRec
end
