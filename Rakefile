years = (2004..2014)

years.each do |year|
  directory "#{year}"

  file "#{year}/mls.txt" => "#{year}" do
    sh "ruby scripts/mls_scraper.rb -y #{year} -o #{year}/mls.txt"
  end
end

task :generate_all_data => years.map { |year| "#{year}/mls.txt"} do
  p "(Re)Generating all fixture data"
end
