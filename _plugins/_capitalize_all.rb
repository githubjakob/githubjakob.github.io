require 'liquid'
require 'uri'

# Capitalize all words of the input
module Jekyll
  module CapitalizeAll
    def capitalize_all(words)
      words.split(/(\s+|\b)/).map do |word|
        if word.match(/\w/)
          word.capitalize
        else
          word
        end
      end.join
    end
  end
end

Liquid::Template.register_filter(Jekyll::CapitalizeAll)