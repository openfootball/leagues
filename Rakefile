#require 'FileUtils'

years = (2005..2014)

years.each do |year|
  directory "#{year}"

  file "#{year}/squads" => "#{year}" do
    sh "mkdir -p #{year}/squads/"
    sh "ruby scripts/mls_scraper.rb -r -y #{year} -o #{year}/squads/ -a teams_us.txt,teams_ca.txt"
  end

  file "#{year}/mls.txt" => "#{year}" do
    sh "ruby scripts/mls_scraper.rb -y #{year} -o #{year}/mls.txt"
  end

  file "#{year}/mls.yml" => "#{year}" do
    yml = "
# MLS Season #{year}

league: mls
season: #{year}
start_at: #{year}-01-01

fixtures:
- mls

teams:
- galaxy
- seattle
- houston
- saltlake
- sanjose
- kansascity
- colorado
- dallas
- chivasusa
- chicago
- columbus
- dcunited
- newengland
- newyork
- philadelphia
- portland
- toronto
- vancouver
- montreal
"
    File.open("#{year}/mls.yml", 'w') {|file| file.write(yml)}
  end
end

desc "Generate all historical fixture data"
task :gen_match_data => years.map { |year| "#{year}/mls.txt"} do
  p "Generated all fixture data"
end

desc "Generate a base .yml file for each year.  Might need manual updates"
task :migrate_yml => years.map {|year| "#{year}/mls.yml"} do
  p "Generated all yml data"
end

desc "Generate the squads for each year"
task :gen_squads => years.map {|year| "#{year}/squads"} do
  p "Generated all squad data"
end

desc "Remove existing match data"
task :clean_match_data do
  p "Are you sure you want remove all match data (Y/N)? "
  response  = $stdin.gets.strip

  if (response =~ /y/i)
    years.each do |year|
      FileUtils.rm("#{year}/mls.txt")
    end
  end
end

desc "Generate all MLS data"
task :all => [:gen_match_data, :migrate_yml, :gen_squads] do
  p "Generated all data!"
end
