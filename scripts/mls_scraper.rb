require 'open-uri'
require 'nokogiri'
require 'logger'
require 'net/http'
# Jaavscript parser
require 'rkelly'

# A command-line utility to parse MLS data into
# openfootball fixtures
class MLSScraper
  # Initialize logging
  # TBD: Determine source?
  def initialize(log_level=Logger::WARN)
    @logger = Logger.new(STDOUT)
    @logger.level = log_level
  end

  def scrape
    doc = Nokogiri::HTML(open("http://data2.7m.cn/matches_data/107/en/index.shtml"))

    url = URI.parse(URI.encode('http://data2.7m.cn/matches_data/107/en/fixture.js'))
    request = Net::HTTP::Get.new(url.path, {'Accept' => '*/*', 'Cache-Control' => 'max-age=0', 'If-Modified-Since' => 'Mon, 30 Jun 2014 02:40:09 GMT', 'If-None-Match' => "a0b2449cc94cf1:0", 'Referer' => 'http://data2.7m.cn/matches_data/107/en/index.shtml'})
    response = Net::HTTP.start(url.host,url.port) { |http|
      http.request(request)
    }

    js = response.body
    @logger.debug("[scrape] Data Response: " + js)

    # Split response into variables
    vars = js.split('var')
    @logger.debug("[scrape] vars: " + vars.to_s)

    # Parse out array vars
    arrays = []
    vars.each do |var|
      arrays.push(parse_js_array(var.strip))
    end

    # Time_Arr is time for each game - what time zone?
    #  3.9.2014 4h25m
    #  3.9.2014 8h00m - 3.8.2014 19:00 EST - 13 hours ahead of EST UTC+1?
    # TeamA_bh vs TeamB_bh @ Time_Arr - Scores_Arr
    times = []
    teamA = []
    teamB = []
    scores = []

    arrays.each do |arr|
      case(arr[:name])
        when "Time_Arr"
          times = arr[:val]
          @logger.debug("[scrape] times: " + times.to_s)
        when "TeamA_Arr"
          teamA = arr[:val]
          @logger.debug("[scrape] teamA: " + teamA.to_s)
        when "TeamB_Arr"
          teamB = arr[:val]
          @logger.debug("[scrape] teamB: " + teamB.to_s)
        when "Scores_Arr"
          scores = arr[:val]
          @logger.debug("[scrape] scores: " + scores.to_s)
      end
    end

    return print_fixture(times,teamA,teamB,scores)
    # Sample CSS
    #match_table = doc.css('#Match_Table table')
    # Sample XPATH
    #details["name"] = doc.search('//meta[@itemprop="name"]').first['content']
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
  def print_fixture(times, teamA, teamB, scores)
    # check parameters
    if (times.size != teamA.size or teamA.size != teamB.size or teamB.size != scores.size or teamB.size != times.size)
      @logger.warn("[parse_fixture] Arrays are not all the same size!")
      @logger.debug("[parse_fixture]     times.size: " + times.size.to_s)
      @logger.debug("[parse_fixture]     teamA.size: " + teamA.size.to_s)
      @logger.debug("[parse_fixture]     teamB.size: " + teamB.size.to_s)
      @logger.debug("[parse_fixture]     scores.size: " + scores.size.to_s)
    end

    ret_s = ""

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

  def self.main
    m = MLSScraper.new
    fixture_data = m.scrape
    File.open("tmp.txt", 'w') {|file| file.write(fixture_data)}
  end
end

# Execute standalone or import
if __FILE__ == $0
  MLSScraper.main
end

