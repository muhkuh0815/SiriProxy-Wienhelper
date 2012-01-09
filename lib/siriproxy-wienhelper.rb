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

#######
# 
# With this plugin you can find public restrooms, drinking fountains and free WiFi Multimediastations in Vienna - Austria.
# Thanks to http://data.wien.gv.at for the data
#
# 	Remember to add the plugin to the "/.siriproxy/config.yml" file!
# 
#######
#
# Das ist ein Plugin um öffentliche WC's, Trinkbrunnen und WLAN Multimediastationen in Wien zu finden.
# Danke an http://data.wien.gv.at für die Daten.
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
#
# Beispiele: Ich brauch ein Klo, Ich brauche ein Taxi, Ich habe Durst, Ich brauche Internet
#
#
# bei Fragen Twitter: @muhkuh0815
# oder github.com/muhkuh0815/SiriProxy-Wienhelper
# Video Preview: noch kein Video
#
#
####  Todo
#
#	gezielte Abfrage mit Loc. - um nicht immer alle Daten laden zu müssen
#
#	preview video
#
#	krankenhäuser
#	mistplätze
#	problemstoffsammelstellen mobil/stationär
#	defibrilatoren
#	schwimmbäder/Badeplatz
#	spielplatz
#	veranstaltungen
#	citybikes
#
######



class SiriProxy::Plugin::Wienhelper < SiriProxy::Plugin
     
    def initialize(config)
    self::class::const_set(:RAD_PER_DEG, 0.017453293)
	self::class::const_set(:Rkm, 6371)              # radius in kilometers...some algorithms use 6367
	self::class::const_set(:Rmeters, 6371000)    # radius in meters
    end

    def dos
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


listen_for /(ich|Wo).*(WC|Klo|toilette|Pinkeln|Häusl|pissen)/i do 
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
	else
		dos ="http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:OEFFWCOGD&srsName=EPSG:4326&outputFormat=json" #&MAXFEATURES=10"
	end
	begin
		dos = URI.parse(URI.encode(dos)) # allows Unicharacters in the search URL
		doc = Nokogiri::HTML(open(dos))
		doc.encoding = 'utf-8'
		doc = doc.text
	rescue Timeout::Error
     	doc = ""
    end
    if doc == ""
    	say "Fehler beim Suchen", spoken: "Fehler beim Suchen" 
    	request_completed
    else
	json = doc.to_s
	empl = json
	empl.chop
	empl.reverse
	empl.chop
	empl.reverse
	empl.gsub('\"', '"')
	empl = JSON.parse(empl)
	busi = empl["features"]
	dat = {}
	if busi == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
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
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "bez" => daab.to_s, "kat" => daakk.to_s, "str" => daas.to_s, "lat" => daala.to_s, "lon" => daalo.to_s, "oef" => daao.to_s}
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
		while z <5 do
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
			say "Ich habe einen Eintrag gefunden."
		else	
			say "Ich habe " + x.to_s + " Einträge gefunden. Ich zeige Dir die 5 Nähesten."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	request_completed
	end
end



listen_for /(ich|Wo).*(Durst|Brunnen|trinken|trinkbrunnen|durstig)/i do 
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
	else
		dos ="http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:TRINKBRUNNENOGD&srsName=EPSG:4326&outputFormat=json" #&MAXFEATURES=10"
	end
	begin
		dos = URI.parse(URI.encode(dos)) # allows Unicharacters in the search URL
		doc = Nokogiri::HTML(open(dos))
		doc.encoding = 'utf-8'
		doc = doc.text
	rescue Timeout::Error
     	doc = ""
    end
    if doc == ""
    	say "Fehler beim Suchen", spoken: "Fehler beim Suchen" 
    	request_completed
    else
	json = doc.to_s
	empl = json
	empl.chop
	empl.reverse
	empl.chop
	empl.reverse
	empl.gsub('\"', '"')
	empl = JSON.parse(empl)
	busi = empl["features"]
	dat = {}
	if busi == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
		busi = busi.to_a
		busi.each do |data|
			coo = data["geometry"]
    		coor = coo["coordinates"]
    		daala = coor[1]
    		daalo = coor[0]
    		daaid = x
    		lon1 = daalo.to_f
			lat1 = daala.to_f
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "id" => daaid.to_s, "lat" => daala.to_s, "lon" => daalo.to_s}
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
		while z <5 do
			da = dat[z]
			da = da[1]
			daala = daala.to_f
			daalo = daalo.to_f
			daae = daae.to_f
			daala = da["lat"]
    		daalo = da["lon"]
    		daaid = da["id"]
    		daae = da["ent"]
    		sname = "Trinkbrunnen" 
    		siri_location = SiriLocation.new(sname, daaid.to_s, "", "9", "AT", "Wien" , daala.to_s , daalo.to_s)
    		map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    		z += 1
 		end
		if x.to_s == 1	
			say "Ich habe einen Eintrag gefunden."
		else	
			say "Ich habe " + x.to_s + " Einträge gefunden. Ich zeige Dir die 5 Nähesten."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	request_completed
	end
end


listen_for /(ich|Wo).*(Taxi|standplatz)/i do 
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
	else
		dos ="http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:TAXIOGD&srsName=EPSG:4326&outputFormat=json" #&MAXFEATURES=10"
	end
	begin
		dos = URI.parse(URI.encode(dos)) # allows Unicharacters in the search URL
		doc = Nokogiri::HTML(open(dos))
		doc.encoding = 'utf-8'
		doc = doc.text
	rescue Timeout::Error
     	doc = ""
    end
    if doc == ""
    	say "Fehler beim Suchen", spoken: "Fehler beim Suchen" 
    	request_completed
    else
	json = doc.to_s
	empl = json
	empl.chop
	empl.reverse
	empl.chop
	empl.reverse
	empl.gsub('\"', '"')
	empl = JSON.parse(empl)
	busi = empl["features"]
	dat = {}
	if busi == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
		busi = busi.to_a
		busi.each do |data|
			coo = data["geometry"]
    		coor = coo["coordinates"]
    		coorr = coor[0]
    		coorrr = coorr[0]
    		daala = coorrr[1]
    		daalo = coorrr[0]
    		daa = data["properties"]
    		daas = daa["ADRESSE"]
    		daao = daa["ZEITRAUM"]
    		lon1 = daalo.to_f
			lat1 = daala.to_f
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "str" => daas.to_s, "lat" => daala.to_s, "lon" => daalo.to_s, "oef" => daao.to_s}
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
		while z <5 do
			da = dat[z]
			da = da[1]
			daala = daala.to_f
			daalo = daalo.to_f
			daae = daae.to_f
			daala = da["lat"]
    		daalo = da["lon"]
    		daas = da["str"]
    		daao = da["oef"]
    		daae = da["ent"]
    		sname = daas.to_s 
    		siri_location = SiriLocation.new(sname, daao.to_s, daao.to_s,"9", "AT", "Wien" , daala.to_s , daalo.to_s)
    		map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    		z += 1
 		end
		if x.to_s == 1	
			say "Ich habe einen Eintrag gefunden."
		else	
			say "Ich habe " + x.to_s + " Einträge gefunden. Ich zeige Dir die 5 Nähesten."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	request_completed
	end
end


listen_for /(ich|Wo).*(WiFi|Wlan|Multimedia|internet)/i do 
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
	else
		dos ="http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:MULTIMEDIAOGD&srsName=EPSG:4326&outputFormat=json" #&MAXFEATURES=10"
	end
	begin
		dos = URI.parse(URI.encode(dos)) # allows Unicharacters in the search URL
		doc = Nokogiri::HTML(open(dos))
		doc.encoding = 'utf-8'
		doc = doc.text
	rescue Timeout::Error
     	doc = ""
    end
    if doc == ""
    	say "Fehler beim Suchen", spoken: "Fehler beim Suchen" 
    	request_completed
    else
	json = doc.to_s
	empl = json
	empl.chop
	empl.reverse
	empl.chop
	empl.reverse
	empl.gsub('\"', '"')
	empl = JSON.parse(empl)
	busi = empl["features"]
	dat = {}
	if busi == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
		busi = busi.to_a
		busi.each do |data|
			coo = data["geometry"]
    		coor = coo["coordinates"]
    		daala = coor[1]
    		daalo = coor[0]
    		daa = data["properties"]
    		daas = daa["ADRESSE"]
    		daao = daa["ZUSATZ"]
    		lon1 = daalo.to_f
			lat1 = daala.to_f
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "str" => daas.to_s, "lat" => daala.to_s, "lon" => daalo.to_s, "zus" => daao.to_s}
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
		while z <5 do
			da = dat[z]
			da = da[1]
			daala = daala.to_f
			daalo = daalo.to_f
			daae = daae.to_f
			daala = da["lat"]
    		daalo = da["lon"]
    		daas = da["str"]
    		daao = da["zus"]
    		daae = da["ent"]
    		sname = daas.to_s 
    		siri_location = SiriLocation.new(sname, daao.to_s, "","9", "AT", "Wien" , daala.to_s , daalo.to_s)
    		map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    		z += 1
 		end
		if x.to_s == 1	
			say "Ich habe einen Eintrag gefunden."
		else	
			say "Ich habe " + x.to_s + " Einträge gefunden. Ich zeige Dir die 5 Nähesten."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	request_completed
	end
end


listen_for /(ich|Wo).*(Polizei)/i do 
	if $maplo == NIL 
		say "Kein GPS Signal", spoken: "Kein GPS Signal"
	else
		dos ="http://data.wien.gv.at/daten/wfs?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:POLIZEIOGD&srsName=EPSG:4326&outputFormat=json" #&MAXFEATURES=10"
	end
	begin
		dos = URI.parse(URI.encode(dos)) # allows Unicharacters in the search URL
		doc = Nokogiri::HTML(open(dos))
		doc.encoding = 'utf-8'
		doc = doc.text
	rescue Timeout::Error
     	doc = ""
    end
    if doc == ""
    	say "Fehler beim Suchen", spoken: "Fehler beim Suchen" 
    	request_completed
    else
	json = doc.to_s
	empl = json
	empl.chop
	empl.reverse
	empl.chop
	empl.reverse
	empl.gsub('\"', '"')
	empl = JSON.parse(empl)
	busi = empl["features"]
	dat = {}
	if busi == NIL
		say "Keine Einträge gefunden."
	else
		lon2 = $maplo
		lat2 = $mapla
		x = 0
		busi = busi.to_a
		busi.each do |data|
			coo = data["geometry"]
    		coor = coo["coordinates"]
    		daala = coor[1]
    		daalo = coor[0]
    		daa = data["properties"]
    		daan = daa["NAME"]
    		daas = daa["ADRESSE"]
    		lon1 = daalo.to_f
			lat1 = daala.to_f
			if lon2 == NIL
				say "Bitte Ortungsdienst einschalten."
			else
				haversine_distance( lat1, lon1, lat2, lon2 )
				entf = @distances['km']
				entf = (entf * 10**3).round.to_f / 10**3
				datt = { "ent" => entf, "str" => daas.to_s, "lat" => daala.to_s, "lon" => daalo.to_s, "nam" => daan.to_s}
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
		while z <5 do
			da = dat[z]
			da = da[1]
			daala = daala.to_f
			daalo = daalo.to_f
			daae = daae.to_f
			daala = da["lat"]
    		daalo = da["lon"]
    		daas = da["str"]
    		daan = da["nam"]
    		daae = da["ent"]
    		sname = daas.to_s 
    		siri_location = SiriLocation.new(sname, daan.to_s, "","9", "AT", "Wien" , daala.to_s , daalo.to_s)
    		map_snippet.items << SiriMapItem.new(label=sname , location=siri_location, detailType="BUSINESS_ITEM")
    		z += 1
 		end
		if x.to_s == 1	
			say "Ich habe einen Eintrag gefunden."
		else	
			say "Ich habe " + x.to_s + " Einträge gefunden. Ich zeige Dir die 5 Nähesten."
		end	
		utterance = SiriAssistantUtteranceView.new("")
    	add_views.views << utterance
    	add_views.views << map_snippet
    	send_object add_views #send_object takes a hash or a SiriObject object
	end
	request_completed
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
 
