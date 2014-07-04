years = (2005..2014)

years.each do |year|
  directory "#{year}"

  file "#{year}/mls.txt" => "#{year}" do
    sh "ruby scripts/mls_scraper.rb -y #{year} -o #{year}/mls.txt"
  end
end

desc "Generate all historical fixture data"
task :generate_all_data => years.map { |year| "#{year}/mls.txt"} do
  p "(Re)Generating all fixture data"
end
