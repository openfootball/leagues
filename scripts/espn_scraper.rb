require 'open-uri'
require 'nokogiri'
require 'logger'
require 'net/http'

class ESPNScraper
  def initialize(options = {})
    @base = "http://www.espnfc.com"
    @logger = Logger.new(STDOUT)
    @logger.level = (options[:verbose]) ? options[:verbose] : Logger::Info
    @roster_file = (options[:file]) ? options[:file] : "roster"
    @team_files = (options[:aux]) ? options[:aux] : []
    @options = options

    # Build up an array 
    lookup_team_keys(@team_files)
  end

  # Load N YAML files to determine what the keys for for each team
  def lookup_team_keys(files)
    @team_keys = {}
    files.each do |file|
      if (file =~ /\.yml/)
        # Try to use the yml directly
        f = YAML.load_file(file)
        @team_keys += f["teams"]
      else
        # Use the teams.txt files because they have more info - easier to match
        File.open(file).each do |line|
          match = /^([A-Za-z0-9_\-]+),/.match(line)
          if(match && match[1])
            @team_keys[match[1]] = line.strip
          end
        end
      end
    end
    @logger.debug("[lookup_team_keys] team_keys: " + @team_keys.to_s)
  end

  def find_key(name)
    @team_keys.each do |key, line|
      if (line =~ /#{name}/i)
        @logger.debug("[find_key] Found #{key} for #{name}")
        return key
      end
    end

    @logger.debug("[find_key] No match for #{name}")
    return "none"
  end

  def scrape
    # Find the URL for each team
    #details["name"] = doc.search('//meta[@itemprop="name"]').first['content']
    doc = Nokogiri::HTML(open("http://www.espnfc.com/major-league-soccer/19/statistics/scorers"))
    clubs_l = doc.css("li.sublist ul li a")
    year = (@options[:year]) ? @options[:year] : 2014

    clubs_l.each do | club |
      club_name = club.content.to_s.strip
      @logger.info("Parsing roster data for " + club_name)
      squad_url = @base + club.attributes["href"].value.to_s.sub(/index/,'squad') + "?season=#{year}"
      @logger.debug("[scrape]   URL: " + squad_url)
      roster = scrape_team_roster(squad_url, year)

      # If there's no data, move on to the next team
      if (roster == [])
        @logger.debug("[scrape] No data for club #{club} in year #{year}")
        next
      else
        fixture_s = generate_fixture(roster)
      end

      club_key = find_key(club_name)
      File.open("#{@roster_file}#{club_key}-#{year.to_s}.txt", 'w') {|file| file.write(fixture_s)}
    end
  end

  def scrape_team_roster(url, year)
    # Return a list of <tr> elements that contain all the necessary player info
    roster = []

    # Check to see if data is available for this year
    doc = Nokogiri::HTML(open(url))

    # Goalkeepers are in their own table
    data = doc.css("div.squad-data-table div.responsive-table div table tbody tr")
    
    data.each do |row|
      # Skip headers
      if (row.children[0].name == "th")
        next
      end

      # Non-headers have stats for each player
      roster.push(row)
      #row.children.each do |child|
        #if child.attributes != nil && child.attributes != {}
          # Add each row to a list of players
          # Helper functions will parse out the interesting information
          #@logger.debug( child.to_s )
          #roster.push(child)
        #end
      #end
    end

    return roster
  end
  
  # Take the scraped data and put it into the proper fixture format
  #  (1)  GK  Sergio Romero                      ##  45, AS Monaco (FRA)
  #
  # *roster* list of NokoGiri row elements containing columns of player data
  def generate_fixture(roster)
    ret = ""

    roster.each do |player|
      name = ""
      number = -1
      pos = "NA"

      player.children.each do |attr|
        if (attr.attributes["class"])
          case(attr.attributes["class"].value)
            when "pla"
              name = attr.content.strip
              @logger.debug("[generate_fixture] Parsing Name: " + name.to_s)
            when "pos"
              pos = attr.content.strip
              @logger.debug("[generate_fixture] Parsing Position: " + pos.to_s)
            when "no"
              number = attr.content.strip
              @logger.debug("[generate_fixture] Parsing Number: " + number.to_s)
          end
        end # if
      end # player.children.each

      # If we parsed out some valid values, create an entry
      if (name != "" and number != -1)
        @logger.debug("[generate_fixture] Adding Player: (#{number}) #{pos} #{name}")
        ret += "(#{number}) #{pos} #{name}\n"
      end
    end # roster.each

    return ret
  end
end
