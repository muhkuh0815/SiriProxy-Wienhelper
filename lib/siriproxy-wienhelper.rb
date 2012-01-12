# -*- encoding: utf-8 -*-
require 'cora'
require 'siri_objects'
require 'eat'
require 'nokogiri'
require 'timeout'
require 'json'
require 'open-uri'
require 'uri'
require 'siren' #for sorting json hashes
#require 'geokit'   tried to find a faster sorting method for the 120.000 tree entries 
#require "./inline_haversine.rb"   cant get it to work, but should be fast

#######
# 
# With this plugin you can find public restrooms, drinking fountains and free WiFi Multimediastations (and much much more)  in Vienna - Austria.
# Thanks to http://data.wien.gv.at for the WFS 1.1.0 data
#
# 	Remember to add the plugin to the "/.siriproxy/config.yml" file!
# 
#######
#
# Das ist ein Plugin um öffentliche WC's, Trinkbrunnen und WLAN Multimediastationen (und viels mehr) in Wien zu finden.
# Danke an http://data.wien.gv.at für die WFS 1.1.0 Daten.
# 
# 	Plugin in "/.siriproxy/config.yml" file hinzufügen !
#
#######
## ##  WIE ES FUNKTIONIERT
#
# "ich|muss|wo" + "Klo|WC|Pinkeln|Häusl"  = suche die nähesten 5 Toiletten in Wien
# 
# "ich|habe" + "Durst|trinken|verdurste" = sucht öffentliche Trinkbrunnen in Wien
#
# "ich|brauche|wo" + "WLAN|internet|WiFi" = sucht WLAN Multimediastationen in Wien
#
# "ich|wo" + "Taxi" = sucht Taxistandplätze in Wien
#
# "ich|wo" + "Polizei" = sucht Polizeistationen in Wien
#
# "ich|wo" + "Baum|Bäume" = durchsucht das Baumkataster in Wien (dauert ca 15sek. >100.000 Einträge)
#
# "ich|wo" + "Citybike|Fahrrad" = sucht Citybikestationen in Wien
#
# "ich|wo" + "Krankenhaus|Spital" = sucht Krankenhäuser in Wien
#
# "ich|wo" + "schwimmen|Hallenbad" = sucht Hallenbäder in Wien
#
# "ich|wo" + "Freibad|Badeplatz" = sucht Badestellen an der Donau in Wien
#
#"ich|wo" + "Museum" = sucht Museen in Wien
#
#"ich|wo" + "Burg|Schloss" = sucht Burgen und Schlösser in Wien
#
#"ich|wo" + "Spielplatz" = sucht Spielplätze in Wien
#
#"ich|wo" + "Sport|Sporthalle" = sucht Sportstätten in Wien
#
#"ich|wo" + "Mistplatz|Müllplatz" = sucht Mistplätze in Wien
#
#"ich|wo" + "Problemstoff" = sucht Problemstoffsammelstellen in Wien
#
#"ich|wo" + "Altstoff|Altglas|Altmetall" = sucht Altglas, Altmetall und Biomüll Container
#
#
# Beispiele: Ich brauch ein Klo, Ich brauche ein Taxi, Ich habe Durst, Ich brauche Internet
#
#
# bei Fragen Twitter: @muhkuh0815
# oder github.com/muhkuh0815/SiriProxy-Wienhelper
# Video Preview: http://www.youtube.com/watch?v=Z6j0UBDdX20
#
#
####  Todo
#
#	gezieltere Abfrage mit Location (BBOX) - um nicht immer alle Daten laden zu müssen
#
#	defibrilatoren
#	veranstaltungen
#
######

class SiriProxy::Plugin::Wienhelper < SiriProxy::Plugin
    #include GeoKit::Mappable
    def initialize(config)
    self::class::const_set(:RAD_PER_DEG, 0.017453293)
	self::class::const_set(:Rkm, 6371)  # radius in kilometers...some algorithms use 6367
	self::class::const_set(:Rmeters, 6371000)   # radius in meters
    end
	def dos
    end
    def doc
    end
    def maplo
    end
    def mapla
    end
     
	filter "SetRequestOrigin", direction: :from_iphone do |object|
    	puts "[Info - User Location] lat: #{object["properties"]["latitude"]}, long: #{object["properties"]["longitude"]}"
    	$maplo = object["properties"]["longitude"]
    	$mapla = object["properties"]["latitude"]
	end 

	def getdata(doc)
		dos = "http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:" + doc + "&srsName=EPSG:4326&outputFormat=json"
		begin
			dos = URI.parse(URI.encode(dos)) # allows Unicharacters in the search URL
			doc = Nokogiri::HTML(open(dos))
			doc.encoding = 'utf-8'
			@doc = doc.text
		rescue Timeout::Error
    	 	@doc = ""
    	end
    	return @doc	
	end


# WC/TOILET SEARCH
listen_for /(ich|Wo).*(WC|Klo|Toilette|pinkeln|Häusl|pissen|stilles Örtchen)/i do 
	response = ask "Brauchst du ein WC, oder tut es auch ein Baum ?"
	if (response =~ /Baum/i)
		baum(40)
	else #nicht Baum
		klo(20)
	end
request_completed
end
# WC/TOILET SEARCH


# TRINKBRUNNEN/DRINKING FOUNTAIN SEARCH
listen_for /(ich|Wo).*(Durst|Brunnen|trinken|trinkbrunnen|durstig)/i do 
	show(10, "TRINKBRUNNENOGD", "", "", "", "Trinkbrunnen")
	request_completed
end

# TAXI/CAB SEARCH
listen_for /(ich|Wo).*(Taxi|standplatz)/i do 
	show(10, "TAXIOGD", "ADRESSE", "ZEITRAUM", "", "Taxistandplätze")
	request_completed
end

# WIFI/INTERNET SEARCH
listen_for /(ich|Wo).*(Wi-Fi|Wlan|Multimedia|internet)/i do 
	show(10, "MULTIMEDIAOGD", "ADRESSE", "ZUSATZ", "", "Multimediastationen")
	request_completed
end

# POLIZEI/POLICE STATION SEARCH
listen_for /(ich|Wo).*(Polizei)/i do 
	show(10, "POLIZEIOGD", "NAME", "ADRESSE", "", "Polizeistationen")
	request_completed
end

# CITY BIKE SEARCH
listen_for /(ich|Wo).*(Radfahren|City bike|fahrrad)/i do 
	show(10, "CITYBIKEOGD", "STATION", "BEZIRK", "", "CityBikestationen")
	request_completed
end

# HOSPITAL SEARCH
listen_for /(ich|Wo).*(Spital|Krankenhaus)/i do 
	show(10, "KRANKENHAUSOGD", "BEZEICHNUNG", "ADRESSE", "", "Spitäler")
	request_completed
end

# SCHWIMMBAD SEARCH
listen_for /(ich|Wo).*(Schwimmen|baden|schwimmbad|hallenbad)/i do 
	show(10, "SCHWIMMBADOGD", "NAME", "ADRESSE", "", "Hallenbäder")
	request_completed
end

# FREIBAD SEARCH
listen_for /(ich|Wo).*(freibad|badeplatz|paradeplatz)/i do 
	show(10, "BADESTELLENOGD", "BEZEICHNUNG", "BEZIRK", "", "Badeplätze an der Donau")
	request_completed
end

# MUSEUM SEARCH
listen_for /(ich|Wo).*(museum)/i do 
	show(10, "MUSEUMOGD", "NAME", "ADRESSE", "BEZIRK", "Museen")
	request_completed
end

# BURG SEARCH
listen_for /(ich|Wo).*(Burg|schloss)/i do 
	show(10, "BURGSCHLOSSOGD", "NAME", "", "", "Burgen")
	request_completed
end

# SPIELPLATZ SEARCH
listen_for /(ich|Wo).*(spielen|Spielplatz)/i do 
	show(10, "SPIELPLATZOGD", "STANDORT", "ANGEBOT", "OEFFNUNGSZEITEN", "Spielplätze")
	request_completed
end

# SPORTSTÄTTEN SEARCH
listen_for /(ich|Wo).*(Sport|Sporthalle)/i do 
	show(10, "SPORTSTAETTENOGD", "SPORTSTAETTEN_ART", "ADRESSE", "KATEGORIE_TXT", "Sportstätten")
	request_completed
end

# MISTPLATZ SEARCH
listen_for /(ich|Wo).*(Mistplatz|Nistplatz|Müllplatz|Mist platz)/i do 
	show(10, "MISTPLATZOGD", "ADRESSE", "OEFFNUNGSZEIT", "", "Mistplätze")
	request_completed
end

# PROBLEMSTOFF SEARCH
listen_for /(ich|Wo).*(Problemstoff|Problem)/i do 
	show(10, "PROBLEMSTOFFOGD", "ADRESSE", "BEZIRK", "OEFFNUNGSZEIT", "Problemstoffsammelstellen")
	request_completed
end

# ALTSTOFFE SEARCH
listen_for /(ich|Wo).*(Glascontainer|Altstoff|altglas|altmetall|container)/i do 
	show(20, "ALTSTOFFSAMMLUNGOGD", "STRASSE", "FRAKTION_TEXT", "", "Altstoffsammelstellen")
	request_completed
end

# BAUM/TREE SEARCH - FROM LOCAL FILE !!
listen_for /(ich|Wo).*(Baum|Bäume|pinkeln)/i do 
	baum(40)	
	request_completed
end

def klo(zz)
	ss = "OEFFWCOGD" 
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
		request_completed
	end
	getdata(ss)
	if @doc == NIL
    	say "Fehler beim Suchen - no data", spoken: "Fehler beim Suchen" 
    	request_completed
    elsif @doc.length < 50
    	say "Fehler beim Suchen - zuwenig Daten", spoken: "Fehler beim Suchen" 
    	request_completed
    else
		empl = JSON.parse(@doc.to_s)
		@doc = ""
		busi = empl["features"]
		if busi == NIL
			say "Keine Einträge gefunden."
		else
			lon2 = $maplo
			lat2 = $mapla
			x = 0
			dat = {}
			busi = busi.to_a
			busi.each do |data|
				coo = data["geometry"]
    			coor = coo["coordinates"]
    			daala = coor[1]
    			daalo = coor[0]
    			daa = data["properties"]
    			daak = daa["KATEGORIE"]
    			daab = daa["BEZIRK"]
    			daas = daa["STRASSE"]
    			daao = daa["OEFFNUNGSZEIT"]
    			if daak == "Behindertenkabine"
    				daakk = "BK"
    			elsif daak == "ohne Personal"
    				daakk = "oP"
    			elsif daak == "Pissoir"
    				daakk = "Pi"
    			elsif daak == "ohne Wartepersonal"
    				daakk = "oP"
    			elsif daak == "Behindertenkabine und Wartepersonal"
    				daakk = "BKmP"
    			elsif daak == "mit Wartepersonal"
    				daakk = "mP"
    			else
    				daakk = "ERROR"
    				y += 1
    			end
    			lon1 = daalo.to_f
				lat1 = daala.to_f
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "bez" => daab.to_s, "kat" => daakk.to_s, "str" => daas.to_s, "lat" => daala.to_s, "lon" => daalo.to_s, "oef" => daao.to_s}
				dat[entf] = datt	
				x += 1
 			end
			datt = Siren.query "$[ /@ ]", dat   #sorting
			dat = datt
			y = 0
			# maps anzeigen
			add_views = SiriAddViews.new
    		add_views.make_root(last_ref_id)
    		map_snippet = SiriMapItemSnippet.new(true)
			z = 0
			while z < zz do
				da = dat[z]
				da = da[1]
				daala = daala.to_f
				daalo = daalo.to_f
				daae = daae.to_f
				daala = da["lat"]
    			daalo = da["lon"]
    			daab = da["bez"]
    			daas = da["str"]
    			daao = da["oef"]
    			daak = da["kat"]
    			daae = da["ent"]
    			sname = daas.to_s 
    			siri_location = SiriLocation.new(sname, daak.to_s + " " + daao.to_s, daab.to_s,"9", "AT", "Wien" , daala.to_s , daalo.to_s)
    			map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    			z += 1
 			end
			if x.to_s == 1	
				say "Ich habe ein WC gefunden."
			else	
				say "Ich habe " + x.to_s + " WC's gefunden. Ich zeige Dir die " + zz.to_s + " Nähesten.", spoken: "Ich habe " + x.to_s + " WC's gefunden."
			end	
			utterance = SiriAssistantUtteranceView.new("")
    		add_views.views << utterance
    		add_views.views << map_snippet
    		send_object add_views #send_object takes a hash or a SiriObject object
		end
		end
end

def show(zz, ss, eins, zwei, drei, auss)
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
		request_completed
	end
	getdata(ss)
    if @doc == NIL
    	say "Fehler beim Suchen - no data", spoken: "Fehler beim Suchen" 
    	request_completed
    elsif @doc.length < 50
    	say "Fehler beim Suchen - zuwenig Daten", spoken: "Fehler beim Suchen" 
    	request_completed
    else
		empl = JSON.parse(@doc.to_s)
		@doc = ""
	busi = empl["features"]
	dat = {}
	if busi == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
		busi = busi.to_a
		print ss
		busi.each do |data|
			coo = data["geometry"]
    		coor = coo["coordinates"]
    		if coo["type"] == "MultiLineString"
    		coorr = coor[0]
    		coorrr = coorr[0]
    		daala = coorrr[1]
    		daalo = coorrr[0]
    		elsif coo["type"] == "MultiPoint"
    		coorr = coor[0]
    		daala = coorr[1]
    		daalo = coorr[0]
    		else
    		daala = coor[1]
    		daalo = coor[0]
    		end
    		daa = data["properties"]
    		daae = daa[eins]
    		daaz = daa[zwei]
    		if drei == ""
    		daad = ""
    		else
    		daad = daa[drei]
    		end    		
    		lon1 = daalo.to_f
			lat1 = daala.to_f
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "eins" => daae.to_s, "zwei" => daaz.to_s, "drei" => daad.to_s, "lat" => daala.to_s, "lon" => daalo.to_s}
				dat[entf] = datt	
			end
    		x += 1
 		end
		datt = Siren.query "$[ /@ ]", dat   #sorting
		dat = datt
		y = 0
		# maps anzeigen
		add_views = SiriAddViews.new
    	add_views.make_root(last_ref_id)
    	map_snippet = SiriMapItemSnippet.new(true)
		z = 0
		while z < zz do
			da = dat[z]
			da = da[1]
			daala = daala.to_f
			daalo = daalo.to_f
			daae = daae.to_f
			daala = da["lat"]
    		daalo = da["lon"]
    		daae = da["eins"]
    		daaz = da["zwei"]
    		if drei == ""
 		   	daad = ""
 		   	else
 		   	daad = da["drei"]
 		   	end
 		   	sname = daae.to_s 
    		siri_location = SiriLocation.new(sname, daaz.to_s, daad.to_s,"9", "AT", "Wien" , daala.to_s , daalo.to_s)
    		map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    		z += 1
 		end
		if x.to_s == 1	
			say "Ich habe einen Eintrag gefunden."
		else	
			say "Ich habe " + x.to_s + " " + auss.to_s + " gefunden. Ich zeige Dir die " + zz.to_s + " Nähesten.", spoken: "Ich habe " + x.to_s + " " + auss.to_s + " gefunden."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	end
end

def baum(zz)
say "need more Power !!!", spoken: ""
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
	else
		# CAREFUL  appx 42 MB !!!
		# dos ="http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:BAUMOGD&srsName=EPSG:4326&outputFormat=json"
	end
	begin
		#read from jstest2 file (42 MB) !!!
		json = File.open("plugins/siriproxy-wienhelper/jstest2", "rb:utf-8")
		doc = json.read
		json.close
	rescue Timeout::Error
     	doc = ""
    end
    if doc == ""
    	say "Fehler beim Suchen", spoken: "Fehler beim Suchen" 
    	request_completed
    else
	json = doc.to_s
	empl = json	
	if empl == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
		xx = 0
		dat = []
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				#webload
				#m1 = Time.now.strftime("%M")
				#s1 = Time.now.strftime("%S")
				
				empl.each_line do |data|
				daa = data.to_s
				#daa = daa.gsub('=>', ':')
				daa = JSON.parse(daa)
				lat1 = daa["lat"].to_f
				lon1 = daa['lon'].to_f
    			
    			# appx 30 sec on my old mac
    			#pa = Geokit::LatLng.new(lat1,lon1)
    			#pb = Geokit::LatLng.new(lat2,lon2)
				#entf = pa.distance_to(pb, :formula => :flat)
    			
    			# 31 sec
    			haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				
				# doesnt work, but should be way faster with inline
				#entf = HaversineInline.distance( lat1, lon1, lat2, lon2)
				
				if entf < 0.2
					daak = daa["kro"]
    				daah = daa["hoe"]
    				daab = daa["umf"]
    				daas = daa["str"]
    				daao = daa["jah"]
					datt = { "ent" => entf, "umf" => daab.to_s, "kro" => daak.to_s, "str" => daas.to_s, "lat" => lat1.to_s, "lon" => lon1.to_s, "jah" => daao.to_s, "hoe" => daah.to_s}
					dat[x] = datt	
					x += 1
				else
				xx += 1
				end
			end
		end
		
		#m2 = Time.now.strftime("%M")
		#s2 = Time.now.strftime("%S")
		#m = m2.to_i - m1.to_i
		#s = s2.to_i - s1.to_i
		#if m = -59
	#		m += 59
	#		s += 60
		#end
		#print m.to_s + ":" + s.to_s

		dat = dat.to_a
		da = dat.to_json
		dat = JSON.parse(da)
		dat = Siren.query "$[ /@.ent ]", dat   #sorting
		y = 0
		# maps anzeigen
		add_views = SiriAddViews.new
    	add_views.make_root(last_ref_id)
    	map_snippet = SiriMapItemSnippet.new(true)
		z = 0
		while z < zz do
			da = dat[z].to_json
			da = JSON.parse(da)
			daala = daala.to_f
			daalo = daalo.to_f
			daae = daae.to_f
			daala = da["lat"].to_f
    		daalo = da["lon"].to_f
    		daab = da["umf"]
    		daas = da["str"]
    		daao = da["jah"]
    		daak = da["kro"]
    		daae = da["ent"]
    		daah = da["hoe"]
    		sname = daao.to_s + " h:" + daah.to_s + "m k:" + daak.to_s + "m u:" + daab.to_s + "cm" 
    		siri_location = SiriLocation.new(sname, daas.to_s, daab.to_s,"9", "AT", "Wien" , daala.to_s , daalo.to_s)
    		map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    		z += 1
 		end
		if z.to_s == 1	
			say "Ich habe einen Eintrag gefunden."
		else	
			say x.to_s + " Bäume in der Nähe. (" + zz.to_s + " von " + xx.to_s + ")", spoken: "Ich habe " + x.to_s + " Bäume gefunden."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	end
end


#    Thanks to http://www.esawdust.com/blog/businesscard/businesscard.html
# for the distance calculation code
def haversine_distance( lat1, lon1, lat2, lon2 )
	
	@distances = Hash.new
	dlon = lon2 - lon1
	dlat = lat2 - lat1
	dlon_rad = dlon * RAD_PER_DEG
	dlat_rad = dlat * RAD_PER_DEG
	lat1_rad = lat1 * RAD_PER_DEG
	lon1_rad = lon1 * RAD_PER_DEG
	lat2_rad = lat2 * RAD_PER_DEG
	lon2_rad = lon2 * RAD_PER_DEG
	a = (Math.sin(dlat_rad/2))**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad/2))**2
	c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))
	dKm = Rkm * c             # delta in kilometers
	dMeters = Rmeters * c     # delta in meters
	@distances["km"] = dKm
	@distances["m"] = dMeters
end


end
 
