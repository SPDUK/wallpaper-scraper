# frozen_string_literal: true

require "json"
require "erb"
require "fileutils"
require "mechanize"
require "cgi"

# used to avoid repeat images
File.write("history.json", {}.to_json) unless File.file?("history.json")
$history = JSON.parse(File.read("history.json"))

$config = JSON.parse(File.read("config.json"))
$save_path = "/home/#{ENV['USER']}/" + $config["save_path"]
# 000 is all disabled, 111 is all enabled
$categories = [0, 1, 2].map { |i| $config["categories"][i] ? 1 : 0 }.join("")
# 010 is enabled, 100 is disabled
$nsfw = $config["nsfw"] ? "010" : "100"
# minimum resolution
$atleast = $config["atleast"]

def search(query)
  agent = Mechanize.new
  enc_query = CGI.escape(query)
  page = 1
  sorting = "relevance"

  url = "https://alpha.wallhaven.cc/search?q=#{enc_query}&categories=#{$categories}&page=#{page}&purity=#{$nsfw}&atleast=#{$atleast}&sorting=#{sorting}&order=desc"

  agent.get(url).links_with(class: /preview/).each do |base|
    id = base.href[/\d+/]
    full_url = "https://wallpapers.wallhaven.cc/wallpapers/full/wallhaven-#{id}.jpg"
    fetch_images(agent, full_url, id)
  end

  File.write("history.json", $history.to_json)
end

def fetch_images(agent, url, id)
  unless $history.key?(id)
    $history[id] = true
    begin
      agent.get(url).save_as($save_path + "#{id}.jpg")
    rescue StandardError
      puts "error with #{url}"
    end
  end
end

def setup_folder
  FileUtils.mkdir_p($save_path) unless File.directory?($save_path)
end

setup_folder
search("space")
