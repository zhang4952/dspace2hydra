# frozen_string_literal: true
require 'yaml'
CONFIG = File.open(File.join(File.dirname(__FILE__), '../.config.yml')) { |f| YAML.safe_load(f) }

require 'nokogiri'
require_relative 'loggable'
require_relative 'bag/bag'
require_relative 'bag/item'
require_relative 'bag/item_file'
require_relative 'metadata'
