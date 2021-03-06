#!/usr/bin/env ruby

# file: mymedia-wiki.rb

require 'mymedia-pages'


class MyMediaWikiError < Exception
end

class MyMediaWikiBase < MyMediaPages
  include RXFileIOModule

  def initialize(media_type: media_type='wiki',
       public_type: @public_type=media_type, ext: '.(html|md|txt)',
                 config: nil, log: nil, debug: false)

    super(media_type: media_type, public_type: @public_type=media_type,
            ext: '.(html|md|txt)', config: config, log: log, debug: debug)

  end

  def copy_publish(filename, raw_msg='')

    @log.info 'MyMediaWiki inside copy_publish' if @log
    @filename = filename
    src_path = File.join(@media_src, filename)


    html_filename = basename(@media_src, src_path).sub(/(?:md|txt)$/,'html')

    FileX.mkdir_p File.dirname(@home + "/#{@public_type}/" + html_filename)
    #FileUtils.write html,  @home + "/#{@public_type}/" + html_filename
    public_path = "#{@public_type}/" + html_filename

    ext = File.extname(src_path)

    raw_destination = "%s/r/%s" % [@home, public_path]
    FileX.mkdir_p File.dirname(raw_destination)
    raw_dest_xml = raw_destination.sub(/html$/,'xml')

    destination = File.join(@home, public_path)

    puts 'raw_destination: ' + raw_destination.inspect if @debug

    x_destination = raw_destination.sub(/\.html$/,ext)

    if @debug then
      puts 'x_destination: ' + x_destination.inspect
      puts '@public_type: ' + @public_type.inspect
    end

    FileX.cp src_path, x_destination

    source = x_destination[/\/r\/#{@public_type}.*/]

    puts 'source: ' + source.inspect if @debug
    s = @website + source
    relative_path = s[/https?:\/\/[^\/]+([^$]+)/,1]

    src_content = FileX.read src_path
    doc = xml(src_content, relative_path, filename)

    return unless doc

    modify_xml(doc, raw_dest_xml)

    tags = doc.root.xpath('summary/tags/tag/text()')
    raw_msg = "%s %s" % [doc.root.text('summary/title'),
            tags.map {|x| "#%s" % x }.join(' ')]

    @log.info 'mymedia-wiki/copy_publish: after modify_xml' if @log

    FileX.write destination, xsltproc("#{@home}/r/xsl/#{@public_type}.xsl",
                                     raw_dest_xml)

    target_url = [@website, @public_type, html_filename].join('/')
    target_url.sub!(/\.html$/,'') if @omit_html_ext

    json_filepath = "%s/%s/dynarex.json" % [@home, @public_type]
    publish_dxlite(json_filepath, {title: raw_msg, url: target_url})
=begin
    msg = "%s %s" % [target_url, raw_msg ]
    sps_message = ['publish', @public_type,
                    target_url, raw_msg]

    send_message(msg: sps_message.join(' '))
=end
    [raw_msg, target_url]

  end

  def delete(id)

    dx = DxLite.new(File.join(@home, @public_type, 'dynarex.json'),
                    autosave: true)

    # Use the id to identify the entry in the dynarex.json file
    rx = dx.find_by_id id
    return unless rx

    # Use the File.basename(url) to identify the file name.
    # Note: Strip out the extension before adding the target ext.
    filename = File.basename(rx.url).sub(/\.html$/,'')

    # Within r/wiki delete the 2 files: .txt and .xml
    FileX.rm File.join(@home, 'r', @public_type, filename + '.txt')
    FileX.rm File.join(@home, 'r', @public_type, filename + '.xml')

    # Within wiki, delete the .html file
    FileX.rm File.join(@home, @public_type, filename + '.html')

    # Delete the entry from the dynarex.json file.
    dx.delete id

  end

  def writecopy_publish(raws)

    s = raws.strip.gsub(/\r/,'')

    title = escape(s.lines[0].chomp)
    filename = title + '.txt'
    FileX.write File.join(@media_src, filename), s

    copy_publish filename
  end


end

class MyMediaWiki < MyMediaWikiBase

  def initialize(media_type: 'wiki', config: nil, newpg_url: '', log: nil,
                 debug: false)

    @url4new = newpg_url
    super(media_type: media_type, config: config, log: log, debug: debug)
  end

  def writecopy_publish(raws)

    # The content to be published might contain 1 or more wiki link
    #    e.g. [[topic2022]] or [[topic2022url|topic2022
    # Here, the link will be transformed to an actual hyperlink which points
    # to a valid wiki page

    s = raws.gsub(/\[\[([^\]]+)\]\]/) do |x|

      puts 'x: ' + x.inspect if @debug
      title = $1
      puts 'searching for title ' + title.inspect  if @debug

      # does the title exist?
      r = find_title(title)

      puts 'r: ' + r.inspect  if @debug

      if r then
        '<a href="' + '/wiki/' + r.title[/^#{title}/i] + '">' + title +'</a>'
      else
        '<a href="' + @url4new + escape(title) + '" class="new" title="' \
            + title + ' (page does not exist)">' + title + '</a>'
      end

    end

    super(s)

  end

  private

  def find_title(s)
    find /^#{s} (?=#)/i
  end

end
