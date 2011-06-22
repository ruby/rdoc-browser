class RDoc::RI::Browser::History

  attr_reader :position

  def initialize
    @pages = []
    @position = 0
  end

  def back
    return if @position == 0

    @position -= 1

    _, content, context = @pages[@position]

    [content, context]
  end

  def forward
    return if @position >= @pages.length - 1

    @position += 1

    _, content, context = @pages[@position]

    [content, context]
  end

  def go name, content, context
    @pages.slice! @position + 1, @pages.length unless
      @position == @pages.length

    @pages << [name, content, context]

    @position = @pages.length - 1
  end

  def pages
    @pages.map { |name,| name }
  end

  def list
    out = RDoc::Markup::Document.new
    out << RDoc::Markup::Heading.new(1, 'History')
    out << RDoc::Markup::BlankLine.new

    unless @pages.empty? then
      list = RDoc::Markup::List.new :NUMBER

      @pages.each_with_index do |(name,_,_), i|
      name = "*#{name}*" if i == @position

      name = RDoc::Markup::Paragraph.new name

      list << RDoc::Markup::ListItem.new(nil, name)
      end

      out << list
    else
      out << RDoc::Markup::Paragraph.new('Your history is empty')
    end

    out
  end
  
end


