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
    #jr 2011-10-09 src_path = File.join(@media_src, filename)
    src_path = filename

    html_filename = basename(@media_src, src_path).sub(/(?:md|txt)$/,'html')

    FileX.mkdir_p File.dirname(@home + "/#{@public_type}/" + html_filename)
    #FileUtils.write html,  @home + "/#{@public_type}/" + html_filename
    public_path = "#{@public_type}/" + html_filename

    ext = File.extname(src_path)

    raw_destination = [@home, @www, 'r', public_path].join('/')
    FileX.mkdir_p File.dirname(raw_destination)
    raw_dest_xml = raw_destination.sub(/html$/,'xml')

    destination = File.join(@home, @www, public_path)

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

    FileX.write destination,
        xsltproc(File.join(@home, @www, 'xsl', @public_type + '.xsl'),
                  raw_dest_xml)    

    target_url = [@website, @public_type, html_filename].join('/')
    target_url.sub!(/\.html$/,'') if @omit_html_ext

    json_filepath = [@home, @www, @public_type, 'dynarex.json'].join('/')
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

    puts 'inside delete ' if @debug
    
    dx = DxLite.new(File.join(@home, @www, @public_type, 'dynarex.json'),
                    autosave: true)

    # Use the id to identify the entry in the dynarex.json file
    rx = dx.find_by_id id
    return unless rx

    # Use the File.basename(url) to identify the file name.
    # Note: Strip out the extension before adding the target ext.
    filename = File.basename(rx.url).sub(/\.html$/,'')

    # Within r/wiki delete the 2 files: .txt and .xml
    FileX.rm File.join(@home, @www,'r',  @public_type, filename + '.txt')
    FileX.rm File.join(@home, @www,'r', @public_type, filename + '.xml')

    # Within wiki, delete the .html file
    FileX.rm File.join(@home, @www, @public_type, filename + '.html')

    # Delete the entry from the dynarex.json file.
    dx.delete id

  end
  

end

class MyMediaWiki < MyMediaWikiBase

  def initialize(media_type: 'wiki', config: nil, newpg_url: '', log: nil,
                 debug: false)
    
    puts 'inside MyMediaWik initialize' if debug
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


class WikiTester23 < MyMediaWiki
  
  # it is assumed this class will be executed from a test directory 
  # containing the following auxillary files:
  #  - wiki.xsl
  #  - index-template.html
  
  def initialize(config: '', cur_dir:  '', debug: false)
    
    @cur_dir = cur_dir
    super(config: config, debug: debug)
    @parent_dir = '/tmp/media'
    @dir = 'wiki'
    
  end

  def cleanup()

    # remove the previous test files
    #
    FileX.rm_r '/tmp/www/*', force: true
    puts 'Previous /tmp/www files now removed!'
  end
  
  def prep()
    
    #return
    # create the template files and directories
    #
    xsl_src = File.join(@cur_dir, 'wiki.xsl')
    www_dest = '/tmp/www/xsl/wiki.xsl'
    r_dest = '/tmp/www/r/xsl/wiki.xsl'      
    index_dest = '/tmp/www/wiki/index-template.html'

    FileX.mkdir_p File.dirname(www_dest)
    FileX.cp xsl_src, www_dest

    FileX.mkdir_p File.dirname(r_dest)
    FileX.cp xsl_src, r_dest

    FileX.mkdir_p File.dirname(index_dest)
    FileX.cp File.join(@cur_dir, 'index-template.html'), '/tmp/www/wiki/index-template.html'

    filepath = File.join(@parent_dir, @dir)
    FileUtils.mkdir_p filepath
  end

  # create the input file
  #  
  def write(filename: '', content: '')

    File.write File.join(@parent_dir, @dir, filename), content
    puts 'debug: filename: ' + filename.inspect

  end
end

