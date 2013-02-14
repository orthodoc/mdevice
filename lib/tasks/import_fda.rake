namespace :fda do
  desc "Import FDA list of companies and products"
  task :import => :environment do
    require 'mechanize'
    require 'fileutils'
    require "zip/zipfilesystem"
    require "charlock_holmes"
    require "date"
    url = 'http://www.fda.gov/MedicalDevices/DeviceRegulationandGuidance/HowtoMarketYourDevice/RegistrationandListing/ucm134495.htm'
    path = File.join(Rails.root,'tmp/zip')
    FileUtils.mkdir_p(path) unless Dir.exist?(path)
    dir = Dir.open(path)
    agent = Mechanize.new do |a|
      a.user_agent_alias = 'Linux Mozilla'
      puts "Visiting webpage".color(:yellow)
      a.get(url)
      links = []
      puts "Collecting links".color(:yellow)
      a.page.search('li li a').to_a.each do |link|
        links << link.attributes['href'].value
      end
      a.pluggable_parser.default = Mechanize::DirectorySaver.save_to(dir)
      puts "Downloading the zip files".color(:yellow)
      links.each do |link|
        a.get(link)
      end
    end
    Dir.chdir(dir) do
      puts "Extracting contents of the zip files".color(:yellow)
      zipfiles = Dir.glob("*.zip")
      zipfiles.each do |zipfile|
        Zip::ZipFile::open(zipfile) do |content|
          content.each do |c|
            c.extract(File.join(dir,c.name))
          end
        end
      end
      txtfiles = Dir.glob("*.txt")
      txtfiles.each do |txtfile|
        contents = File.read(txtfile)
        detection = CharlockHolmes::EncodingDetector.detect(contents)
        puts "Converting the #{txtfile} encoding from #{detection[:encoding]} to UTF-8".color(:green)
        #===========================================================================================
        ## One of the txt files returned nil char coding and this produced a segfault in ruby.
        ## This block bypasses that by assuming that the nil coding is in real ISO-8859-1 or LATIN1
        ## If you have a better solution (I am sure there is one!), Please substitute this.
        #===========================================================================================
        if detection[:encoding] == nil
          utf8_contents = CharlockHolmes::Converter.convert contents, 'ISO-8859-1', 'UTF-8'
        else
          utf8_contents = CharlockHolmes::Converter.convert contents, detection[:encoding], 'UTF-8'
        end
        new_path = File.join(Rails.root, 'tmp/zip/utf8')
        FileUtils.mkdir_p(new_path) unless Dir.exist?(new_path)
        new_dir = Dir.open(new_path)
        new_contents = File.new(File.join(new_dir,File.path(txtfile)), 'w')
        new_contents.write(utf8_contents)
        new_contents.close
        Dir.chdir(new_dir) do
          #utf8_files = Dir.glob("*.txt")
        end
      end
    end
    #FileUtils.rm_rf(path)
  end
end
