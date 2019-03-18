# frozen_string_literal: true

require "json"
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

def search(query, categories, nsfw, ratios, atleast, pages)
  agent = Mechanize.new
  enc_query = CGI.escape(query)

  # todo: scrape the amount of maximum pages before starting, then go up to pages or the max amount
  1.upto(pages) do |page|
    url = "https://alpha.wallhaven.cc/search?q=#{enc_query}&categories=#{categories}&page=#{page}&purity=#{nsfw}&ratios=#{ratios}&atleast=#{atleast}&sorting=relevance&order=desc"

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
query = prompt.ask("What would you like to search for?").capitalize

get_categories = prompt.multi_select("Which categories?") do |menu|
  %w(general anime people)
  menu.default 1, 2, 3
  menu.choice :general, 0
  menu.choice :anime, 1
  menu.choice :people, 2
end
# categories are a multi-select but .multi_select doesn't return an array of the same size
# so we have to figure out which ones go where and replace the 0s if they should be replaced
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


ratio_options = %w(4x3 16x9 16x10 32x9 48x9 9x16 10x16)
ratios = prompt.multi_select("Which aspect ratios? Default finds them all", ratio_options).join("%2C")

resolutions = %w(1280x720 1600x900 1920x1080 2560x1440 3840x2160)
atleast = prompt.select("What is the minimum resolution you'd like to find?", resolutions)

pages = prompt.slider("How many pages would you like to find?", min: 1, max: 20, default: 1, step: 1)

# start search spinner and begin
spinner = TTY::Spinner.new("[:spinner] Searching for #{query}...", format: :dots)
spinner.auto_spin
setup_folder()
search(query, categories, nsfw, ratios, atleast, pages)


# open the folder when done
files = Dir["#{$save_path}#{query}/*"]
if files.length > 0
  spinner.success("Done! #{files.length} Files saved in file://#{$save_path}#{query}")
  if prompt.yes?("Would you like to set a background using one of the images you just downloaded?")
    `gsettings set org.gnome.desktop.background picture-uri file://#{files.sample}`
  end
  prompt.say("[✔] Finished!")
else
  spinner.error("Could not find any wallpapers for #{query} with those options")
end
