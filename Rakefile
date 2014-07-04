years = (2005..2014)

years.each do |year|
  directory "#{year}"

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
task :generate_all_data => years.map { |year| "#{year}/mls.txt"} do
  p "Generated all fixture data"
end

desc "Generate a base .yml file for each year.  Might need manual updates"
task :migrate_yml => years.map {|year| "#{year}/mls.yml"} do
  p "Generated all yml data"
end
