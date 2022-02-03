#!/usr/bin/env ruby

# file: mymedia-wiki.rb

require 'mymedia-pages'


class MyMediaWikiError < Exception
end

class MyMediaWiki < MyMediaPages

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

    FileUtils.mkdir_p File.dirname(@home + "/#{@public_type}/" + html_filename)
    #FileUtils.write html,  @home + "/#{@public_type}/" + html_filename
    public_path = "#{@public_type}/" + html_filename

    ext = File.extname(src_path)

    raw_destination = "%s/r/%s" % [@home, public_path]
    FileUtils.mkdir_p File.dirname(raw_destination)
    raw_dest_xml = raw_destination.sub(/html$/,'xml')

    destination = File.join(@home, public_path)

    puts 'raw_destination: ' + raw_destination.inspect if @debug

    x_destination = raw_destination.sub(/\.html$/,ext)

    if @debug then
      puts 'x_destination: ' + x_destination.inspect
      puts '@public_type: ' + @public_type.inspect
    end

    FileUtils.cp src_path, x_destination

    source = x_destination[/\/r\/#{@public_type}.*/]

    puts 'source: ' + source.inspect if @debug
    s = @website + source
    relative_path = s[/https?:\/\/[^\/]+([^$]+)/,1]

    src_content = File.read src_path
    doc = xml(src_content, relative_path, filename)

    return unless doc

    modify_xml(doc, raw_dest_xml)

    tags = doc.root.xpath('summary/tags/tag/text()')
    raw_msg = "%s %s" % [doc.root.text('summary/title'),
            tags.map {|x| "#%s" % x }.join(' ')]

    @log.info 'mymedia-wiki/copy_publish: after modify_xml' if @log

    File.write destination, xsltproc("#{@home}/r/xsl/#{@public_type}.xsl",
                                     raw_dest_xml)

    target_url = [@website, @public_type, html_filename].join('/')

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

  def writecopy_publish(raws)

    s = raws.strip.gsub(/\r/,'')

    title = escape(s.lines[0].chomp)
    filename = title + '.txt'
    File.write File.join(@media_src, filename), s

    copy_publish filename
  end

  private

  def escape(s)
    s.gsub(/ +/,'_')#.gsub(/'/,'%27')
  end


end
