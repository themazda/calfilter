require 'open-uri'
require 'rss'
require 'rexml/document'

syoboUrl = "http://cal.syoboi.jp/rss2.php?usr="+ARGV[0].to_s+"&filter=0&count=150&ssch=1&days=1&titlefmt=%24(TID)%7c%5f%7c%24(PID)%7c%5f%7c%24(Count)%7c%5f%7c%24(Title)%7c%5f%7c%24(SubTitleB)"

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
=begin
	tid = titleString[/([0-9]+)\|\_\|([0-9]+)/, 1]
	pid = titleString[/([0-9]+)\|\_\|([0-9]+)/, 2]
	count = titleString[/([0-9]+)\|\_\|([0-9]+)\|\_\|([0-9]+)/, 3]
	dirtyProgramName = titleString[/([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)/, 4]
	subtitleB = titleString[/([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)\|\_\|([\S\s]+)/, 5]
=end
	tid = titleString[/([0-9]+|)\|\_\|([0-9]+|)\|\_\|([0-9]+|)\|\_\|([\S\s]+|)\|\_\|([\S\s]+|)/, 1]
	pid = titleString[/([0-9]+|)\|\_\|([0-9]+|)\|\_\|([0-9]+|)\|\_\|([\S\s]+|)\|\_\|([\S\s]+|)/, 2]
	count = titleString[/([0-9]+|)\|\_\|([0-9]+|)\|\_\|([0-9]+|)\|\_\|([\S\s]+|)\|\_\|([\S\s]+|)/, 3]
	dirtyProgramName = titleString[/([0-9]+|)\|\_\|([0-9]+|)\|\_\|([0-9]+|)\|\_\|([\S\s]+|)\|\_\|([\S\s]+|)/, 4]
	subtitleB = titleString[/([0-9]+|)\|\_\|([0-9]+|)\|\_\|([0-9]+|)\|\_\|([\S\s]+|)\|\_\|([\S\s]+|)/, 5]
	#puts titleString
	#print(tid, ",", pid, ",", count, ",", dirtyProgramName, ",", subtitleB, "\n")

	if tid != "" and pid != 0 and count != ""
		programName = dirtyProgramName.rstrip
	end

	# sybocalに登録されているが複数話放送の可能性。
	if tid != "" and pid != 0 and count == ""
		# とりあえず一枠一話のみ対応
		count = subtitleB[/\#([0-9]+)/, 1]
		programName = dirtyProgramName[/(.*?)\#[0-9]+/, 1].to_s.rstrip
		if programName == nil
			programName = dirtyProgramName.rstrip
		end
	end

	# syobocalに登録されているが映画など話数の無い作品
	if tid != "" and pid == 0
		# とりあえず一枠一話のみ対応
		#counts = dirtyProgramName.split(/.*?\#([0-9]+)/)
		count = dirtyProgramName[/\#([0-9]+)/, 1]
		programName = dirtyProgramName[/(.*?)\#[0-9]+/, 1].to_s.rstrip
		if programName == nil
			programName = dirtyProgramName.rstrip
		end
	end
	# syobocalからtidが見つからなかった場合
	if tid == ""
		# とりあえず一枠一話のみ対応
		#counts = dirtyProgramName.split(/.*?\#([0-9]+)/)
		count = dirtyProgramName[/\#([0-9]+)/, 1]
		programName = dirtyProgramName[/(.*?)\#[0-9]+/, 1].to_s.rstrip
		if programName == nil
			programName = dirtyProgramName.rstrip
		end
	end

	# syobocalに無いわ映画だわ
	if count == nil
		count = 0
	end
	#print(tid, ",", pid, ",", count, ",", programName, "\n")
	
	return tid, pid, count, programName
end

def isValidEpisode(elem)
	if elem.attributes.get_attribute("TID") != nil and elem.attributes.get_attribute("PID") != nil and elem.attributes.get_attribute("TITLE") != nil and elem.attributes.get_attribute("COUNT") != nil
		return true
	end
	return false
end

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
			return elem.attributes.get_attribute("TITLE").value
		end
	}
	#print("False\n")
	return nil
end

def findTidAndPid(elems, title, count)
	elems.each {|elem|
		if elem.attributes.get_attribute("TITLE").value == title and elem.attributes.get_attribute("COUNT").value == count
			tid = elem.attributes.get_attribute("TID").value
			pid = elem.attributes.get_attribute("PID").value
			return tid, pid
		end
	}
	return nil,nil
end

xmldoc = nil
File.open(xmlFileName) do |syoboXML|
	xmldoc = REXML::Document.new(syoboXML)
end

xmldoc.root.elements.each {|elem|
	if isValidEpisode(elem) == false
		xmldoc.root.delete_element(elem)
	end
}

elems = xmldoc.root.elements
attrs = xmldoc.root.attributes

syoboRss = getRss(syoboUrl)
#printRss(syoboRss)
#puts syoboRss.to_s
syoboRss.items.each do |item|
	tid, pid, count, programName = parseTitle(item.title)
	if tid == ""
		tid, pid = findTidAndPid(elems, programName, count)
		if (tid != nil and pid != nil )
			item.link = "http://cal.syoboi.jp/tid/%s\#%s" % [tid, pid]
		end
	else
		# TIDをキーにDBに番組が登録されているかどうかを確認し、なければ追加する
		if findEpisode(elems, tid, pid) == 0
			addelem = REXML::Element.new("program")
			addelem.add_attribute("TID", tid)
			addelem.add_attribute("PID", pid)
			addelem.add_attribute("COUNT", count)
			addelem.add_attribute("TITLE", programName)
			elems.add(addelem)
		end
	end
end
#puts syoboRss.to_s
File.open(xmlFileName, "w") do |outfile|
	xmldoc.write(outfile,0)
end
