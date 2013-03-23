require 'open-uri'
require 'rss'
require 'rexml/document'

syoboUrl = "http://cal.syoboi.jp/rss2.php?usr="+ARGV[0].to_s+"&filter=0&count=10&ssch=1&days=1&titlefmt=%24(TID)%7c%5f%7c%24(PID)%7c%5f%7c%24(Count)%7c%5f%7c%24(Title)"

titleInfoUrlString = "http://cal.syoboi.jp/db.php?Command=TitleLookup&TID=*&LastUpdate=%d_000000-%d_000000&Fields=TID,Title"

subTitleInfoUrlString = "http://cal.syoboi.jp/db.php?Command=ProgLookup&Range=%d_000000-%d_000000&JOIN=SubTitles&Fields=TID,"
xmlFileName = "syobocal.xml"

def getRss(url)
	return open(url){|file| RSS::Parser.parse(file.read, false)}
end

def printRss(rss)
	rss.items.each do |item|
	# title and links
	# タイトルは、TID、PID、話数、番組名、話数、サブタイトル、[放送局]
		puts item.title

	# linkは、http://cal.syoboi.jp/tid/<tid>#<話数ID>
		p item.link
	#	p item.description
		parseTitle(item.title)
	end
end

# URIからTIDを返す。存在しない場合はnil
def getTid(uriString)
	uri = URI.parse(uriString)
	return uri.path[/[0-9]+/]
end

# タイトルの解析
def parseTitle(titleString)
	tid = titleString[/([0-9]+)\|\_\|([0-9]+)/, 1]
	pid = titleString[/([0-9]+)\|\_\|([0-9]+)/, 2]
	count = titleString[/([0-9]+)\|\_\|([0-9]+)\|\_\|([0-9]+)/, 3]
	dirtyProgramName = titleString[/([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)/, 4]
	# puts dirtyProgramName
	puts titleString
	# syobocalからtidが見つからなかった場合
	if tid == nil
		# とりあえず一枠一話のみ対応
		dirtyProgramName = titleString[/[^(\|\_\|0\|\_\|\|\_\|)].*/]
		count = dirtyProgramName[/^.*\#([0-9]+)/, 1]
		programName = dirtyProgramName[/(^.*)\#[0-9]+/, 1]
		if programName == nil
			programName = dirtyProgramName
		end
	else 
		if pid == 0
			# とりあえず一枠一話のみ対応
			dirtyProgramName = titleString[/[^(0-9\|\_\|0\|\_\|\|\_\|)].*/]
			count = dirtyProgramName[/^.*\#([0-9]+)/, 1]
			programName = dirtyProgramName[/(^.*)\#[0-9]+/, 1]
			if programName == nil
				programName = dirtyProgramName
			end
		else
			programName = dirtyProgramName
		end
	end
	if count == nil
		count = 0
	end
	
	print(tid, ",", pid, ",", count, ",", programName, "\n")
	
	return tid, pid, count, programName
end

=begin
 todo 有効な番組情報をキャッシュで持つ(番組名, TID, 話数, epID)
 キャッシュファイルの取得
 取得した要素のうち、TIDが0であればキャッシュから番組情報を取得
 なければ出力対象から外す

 やはり番組情報をDB上で管理したほうが良さそう
 	* TID
 	* syobocal番組名
 	* syobocalサブタイトルID
 	* syobocalサブタイトル
	* 話数
=end

def findEpisode(elems, tid, pid)
	elems.each {|elem|
		attr_tid = elem.attributes.get_attribute("TID")
		if attr_tid != nil and attr_tid.value == tid
			attr_pid = elem.attributes.get_attribute("PID")
			if attr_pid != nil and attr_pid.value == pid
				return 1
			end
		end
	}
	return 0
end
		
def findProgramNameFromTid(elems, tid, pid)
	elems.each {|elem|
		#print(tid, " ", elem.attributes.get_attribute("TID").value, "\n")
		if elem.attributes.get_attribute("TID").value == tid
		#	puts elem.text
		#	print("True\n")
			return elem.text
		end
	}
	#print("False\n")
	return nil
end

xmldoc = nil
File.open(xmlFileName) do |syoboXML|
	xmldoc = REXML::Document.new(syoboXML)
end
elems = xmldoc.root.elements
attrs = xmldoc.root.attributes

syoboRss = getRss(syoboUrl)
#printRss(syoboRss)
#puts syoboRss.to_s
syoboRss.items.each do |item|
	tid, pid, count, programName = parseTitle(item.title)
	if tid == 0
		item.link = "http://cal.syoboi.jp/tid/%s\#%s" % [tid, epNo]
	else
		# TIDをキーにDBに番組が登録されているかどうかを確認し、なければ追加する
		if findEpisode(elems, tid, pid) == 0
			addelem = REXML::Element.new("program")
			addelem.add_attribute("TID", tid)
			addelem.add_text(programName)
			addelem.add_attribute("PID", pid)
			addelem.add_text(count.to_s)
			elems.add(addelem)
		end
	end
end
#puts syoboRss.to_s
File.open(xmlFileName, "w") do |outfile|
	xmldoc.write(outfile,0)
end
=begin

=end
