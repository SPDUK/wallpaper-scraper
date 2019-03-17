# frozen_string_literal: true

require "json"
require "erb"
require "fileutils"
require "mechanize"
require "cgi"
require "tty/prompt"
require "tty/spinner"
prompt = TTY::Prompt.new(enable_color: true)

# used to avoid repeat images
File.write("history.json", {}.to_json) unless File.file?("history.json")
$history = JSON.parse(File.read("history.json"))
$save_path = "/home/#{ENV['USER']}/Pictures/Wallpapers/"

def search(query, categories, nsfw, atleast, pages)
  agent = Mechanize.new
  enc_query = CGI.escape(query)

  1.upto(pages) do |page|
    url = "https://alpha.wallhaven.cc/search?q=#{enc_query}&categories=#{categories}&page=#{page}&purity=#{nsfw}&atleast=#{atleast}&sorting=relevance&order=desc"

    agent.get(url).links_with(class: /preview/).each do |base|
      id = base.href[/\d+/]
      full_url = "https://wallpapers.wallhaven.cc/wallpapers/full/wallhaven-#{id}.jpg"
      fetch_images(agent, full_url, query, id)
    end
  end

  File.write("history.json", $history.to_json)
end

def fetch_images(agent, url, query, id)
  unless $history.key?(id)
    $history[id] = true
    begin
      agent.get(url).save_as($save_path + "#{query}/#{id}.jpg")
    rescue; end
  end
end

def setup_folder
  FileUtils.mkdir_p($save_path) unless File.directory?($save_path)
end


# questions to know what to search for
query = prompt.ask("What would you like to search for?")

get_categories = prompt.multi_select("Which categories?") do |menu|
  %w(general anime people)
  menu.default 1, 2, 3
  menu.choice :general, 0
  menu.choice :anime, 1
  menu.choice :people, 2
end

categories = ["0", "0", "0"]
get_categories.each { |i| categories[i] = "1" }
categories = categories.join("")

nsfw = prompt.select("Would you like to find potentially NSFW images?") do |menu|
  %w(yes no both)
  menu.default 1, 2, 3
  menu.choice :yes, "010"
  menu.choice :no, "100"
  menu.choice :both, "110"
end

resolutions = %w(1280x720 1600x900 1920x1080 2560x1440 3840x2160)
atleast = prompt.select("What is the minimum resolution you'd like to find?", resolutions)

pages = prompt.slider("How many pages would you like to find?", min: 1, max: 20, step: 1)

# start search spinner and begin
spinner = TTY::Spinner.new("[:spinner] Searching for #{query}...", format: :dots)
spinner.auto_spin
setup_folder()
search(query, categories, nsfw, atleast, pages)

# open the folder when done
spinner.success("Done! Files saved in /#{$save_path}#{query}")
`nautilus #{$save_path}/#{query}`
