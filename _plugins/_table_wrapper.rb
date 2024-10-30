## taken from https://gist.github.com/kinoute/c2db61fa6549f474948a5c3937efde9f
Jekyll::Hooks.register :documents, :post_render do |doc|
  doc.output.gsub! /<table>/, '<div class="table-wrapper" markdown="block"><table>'
  doc.output.gsub! /<\/table>/, '</table></div>'
end