require 'open-uri'
#require 'nokogiri'
require 'logger'
require 'net/http'
require 'optparse'
require_relative 'espn_scraper'

# A command-line utility to parse MLS data into
# openfootball fixtures
class MLSScraper
  attr_accessor :arrays

  # Initialize logging
  # TBD: Determine source?
  def initialize(options)
    @logger = Logger.new(STDOUT)
    @logger.level = (options[:verbose] != nil) ? options[:verbose] : Logger::WARN
    @logger.debug(options.to_s)

    # Do this in ESPN Scraper instead
    #@gen_roster = (options[:roster] != nil) ? options[:roster] : true
    @gen_roster = false

    @options = options
  end

  # Slightly improved JS array parsing
  # Requires array be all on one line
  # Allows for 2D arrays
  def parse_js_array_v2(js)
    lines = js.split(/\r\n/)
    arrays = []

    lines.each do |line|
      # Parse out the name index and array
      match = /([0-9A-Za-z_\-]+)\[?(\d?\d?)\]?\s*=\s*(\[.*\])/.match(line)
      
      if (match.kind_of?(MatchData))
        @logger.info("[parse_js_array_v2] " + match.to_s)
        arr = {}
        matched = false
        arr[:name] = match[1]
        sanitized_val = match[3]

        # Some teams have an (N) post fix
        if (arr[:name] =~ /team/i)
          sanitized_val = match[3].gsub(/\(N\)/,'')
        end

        arr[:val] = eval(sanitized_val)

        # Check if the name already exists.  If so, it will become an array of arrays (2D)
        arrays.each do |a|
          if (a[:name] == arr[:name])
            matched = true
            a[:val][match[2].to_i] = eval(sanitized_val)
          end
        end

        # If it doesn't exist, set the value directly
        if (not matched)
          arrays.push(arr)
        end
      end # end match
    end # end each

    return arrays
  end

  # Format a URL for historical data, and return a request
  def get_historical_game_data(year)
    url_s = (year.to_i < 2008) ? "http://data2.7m.cn/history_matches_data/#{year}/107/en/index.shtml" : "http://data2.7m.cn/history_matches_data/#{year}/107/en/matches.js"
    url = URI.parse(URI.encode(url_s))
    request = Net::HTTP::Get.new(url.path, {'Accept' => '*/*', 'Cache-Control' => 'max-age=0', 
      'If-Modified-Since' => 'Mon, 30 Jun 2014 02:40:09 GMT', 'If-None-Match' => "bcb08f55c6f3ce1:bed4", 
      'Referer' => "http://data2.7m.cn/history_matches_data/#{year}/107/en/index.shtml"})

    js = get_response(url, request)
    @logger.debug("[get_historical_game_data] Data Response: " + js)

    # These arrays have a different format
    # s_name_arr = [ 'Qualifying','Play-offs','Quarter Final','Semifinal','Final'];
    # Some arrays are 2D, with first index corresponding to s_name_arr index
    @arrays = parse_js_array_v2(js)
    return parse_arrays(@arrays)
  end

  def get_response(url, request)
    response = Net::HTTP.start(url.host,url.port) { |http|
      http.request(request)
    }

    return response.body
  end

  def scrape
    #doc = Nokogiri::HTML(open("http://data2.7m.cn/matches_data/107/en/index.shtml"))

    url = URI.parse(URI.encode('http://data2.7m.cn/matches_data/107/en/fixture.js'))
    request = Net::HTTP::Get.new(url.path, {'Accept' => '*/*', 'Cache-Control' => 'max-age=0', 'If-Modified-Since' => 'Mon, 30 Jun 2014 02:40:09 GMT', 'If-None-Match' => "a0b2449cc94cf1:0", 'Referer' => 'http://data2.7m.cn/matches_data/107/en/index.shtml'})

    js = get_response(url,request)
    @logger.debug("[scrape] Data Response: " + js)

    arrays = js_to_ruby(js)
    return parse_arrays(arrays)
  end

  # Convert javascript arrays, +js+, into ruby arrays
  def js_to_ruby(js)
    # Split response into variables
    vars = js.split('var')
    @logger.debug("[scrape] vars: " + vars.to_s)

    # Parse out array vars
    arrays = []
    vars.each do |var|
      arrays.push(parse_js_array(var.strip))
    end

    return arrays
  end

  # Take a hash of javascript +arrays+ and find
  # the ones with useful information about the game
  #
  # Return a string representing the parsed fixture
  def parse_arrays(arrays)
    # Time_Arr is time for each game - what time zone?
    #  3.9.2014 4h25m
    #  3.9.2014 8h00m - 3.8.2014 19:00 EST - 13 hours ahead of EST UTC+1?
    # TeamA_bh vs TeamB_bh @ Time_Arr - Scores_Arr
    times = []
    teamA = []
    teamB = []
    scores = []
    rounds = []
    teamA_ids = []
    ret = ""

    arrays.each do |arr|
      case(arr[:name])
        when "Start_time_arr", "Time_Arr"
          times = arr[:val]
          @logger.debug("[scrape] times: " + times.to_s)
        when "TeamA_Arr", "TeamA_arr"
          teamA = arr[:val]
          @logger.debug("[scrape] teamA: " + teamA.to_s)
        when "TeamB_Arr", "TeamB_arr"
          teamB = arr[:val]
          @logger.debug("[scrape] teamB: " + teamB.to_s)
        when "score_arr", "Scores_Arr"
          scores = arr[:val]
          @logger.debug("[scrape] scores: " + scores.to_s)
        when "s_name_arr"
          rounds = arr[:val]
          @logger.debug("[scrape] rounds: " + rounds.to_s)
        when "TeamA_bh_arr"
          teamA_ids = arr[:val]
          @logger.debug("[scrape] teamA_ids: " + rounds.to_s)
      end
    end

    # Generate rosters
    if (@gen_roster)
      if rounds.size > 0
        print_rosters(teamA[0], teamA_ids[0])
      else
        print_rosters(teamA, teamA_ids)
      end
    end

    # Different queries will have different formats
    #   Historical game data will have 2D arrays organized into rounds
    #   s_name_arr holds the rounds.  If this exists, we will parse the fixture
    #   into rounds
    if (rounds.size > 0)
      rounds.each_with_index do |round, i|
        ret += print_fixture(rounds[i],times[i],teamA[i],teamB[i],scores[i]) + "\n"
      end
    else
      # Otherwise, assume current year data
      ret = print_fixture("Qualifying",times,teamA,teamB,scores)
    end

    return ret
  end

  # Query for each team's roster
  def print_rosters(team_names, team_ids)
    teams = {}

    team_names.each_with_index do |team, i|
      teams[team] = team_ids[i]
    end

    @logger.debug(teams)

    # URL for team data
    url_s = "http://data2.7m.cn/team_data/347/en/index.shtml"
  end

  # Return a hash {name: "foo", val: [bar]}
  # Expects something of the form: "var foo = [bar];"
  def parse_js_array(arr)
    match = /(\S+)\s*=/.match(arr)
    name = ""
    ret = {name: "", val: []}
    @logger.debug("[parse_js_array] arr: " + arr)
    @logger.debug("[parse_js_array] name_match: " + match.to_s)

    if (match.kind_of?(MatchData) and match[1] != nil)
      @logger.debug("[parse_js_array] setting name to " + match[1].to_s)
      ret[:name] = match[1]
    else
      # Not the format we expect, so move along
      return ret
    end

    match = /=\s*(\[.*\]);/.match(arr)
    if (match.kind_of?(MatchData) and match[1] != nil)
      @logger.debug("[parse_js_array] setting array to " + match[1].to_s)
      arr_s = match[1]
      # Convert string to ruby array
      # TODO: parse this manually for increased security
      ret[:val] = eval(arr_s)
    else
      return ret
    end
    
    return ret
  end

  # Convert associated arrays of time, teams, and scores
  # to openfootball fixture format
  #  Example:
  #  Sun Mar/9 D.C. United            0-3   Columbus Crew
  def print_fixture(round, times, teamA, teamB, scores)
    # check parameters
    if (times.size != teamA.size or teamA.size != teamB.size or teamB.size != scores.size or teamB.size != times.size)
      @logger.warn("[parse_fixture] Arrays are not all the same size!")
      @logger.debug("[parse_fixture]     times.size: " + times.size.to_s)
      @logger.debug("[parse_fixture]     teamA.size: " + teamA.size.to_s)
      @logger.debug("[parse_fixture]     teamB.size: " + teamB.size.to_s)
      @logger.debug("[parse_fixture]     scores.size: " + scores.size.to_s)
    end

    ret_s = "#{round}\n\n"

    times.each_with_index do |t, i|
      # convert time to proper format
      date = DateTime.strptime(t, "%Y,%m,%d,%H,%M,%S")
      # Subtract 13 hours to get into EST time
      time = date.to_time - (60*13*60)
      date_s = time.strftime("%a %b/%-d %H:%M")
      # Parse out the score
      # Example:
      # 1-1(0-0)
      score_s = scores[i].sub(%r{\(.*\)}, '')
      spacing = "           "

      @logger.debug("[parse_fixture] " + date_s + " " + teamA[i] + spacing + score_s + " " + teamB[i])
      ret_s += date_s + " " + teamA[i] + spacing + score_s + " " + teamB[i] + "\n"
    end

    return ret_s
  end


end

# Parse the command-line
def parse_options
  options = {}

  # Some defaults
  options[:file] = "temp"
  options[:verbose] = Logger::WARN
  options[:year] = 2014

  opts = OptionParser.new do |opt|
    opt.banner = "Usage: mls_scraper.rb [-o FILE -y YEAR -d games|teams|roster -v]"

    opt.on('-v', '--verbose', 'Print debug information') do 
      options[:verbose] = Logger::DEBUG
    end

    opt.on('-o', '--output FILE', 'Output resuls to FILE') do |file|
      options[:file] = file
    end

    opt.on('-y', '--year YEAR', 'Get historical data for YEAR') do |year|
      options[:year] = year
    end

    opt.on('-r', '--roster roster', 'Get historical data for roster') do
      options[:roster] = true
    end
  end

  opts.parse!
  return options
end

# Parse options and start the scraping
def main
  options = parse_options
  fixture_data = ""
  m = MLSScraper.new(options)

  if(options[:roster])
    e = ESPNScraper.new(options)
    e.scrape
  else
    # Current year is a different API
    if (options[:year].to_i == Date.today.year)
      fixture_data = m.scrape
    else
      fixture_data = m.get_historical_game_data(options[:year])
    end
    File.open(options[:file], 'w') {|file| file.write(fixture_data)}
  end # not roster
end

# Execute standalone or import
if __FILE__ == $0
 main
end

