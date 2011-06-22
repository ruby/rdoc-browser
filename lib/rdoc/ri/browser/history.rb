##
# History for the ri browser.
#
# History items have a name, content and context for generating hyperlinks.

class RDoc::RI::Browser::History

  ##
  # The currently displayed page in the history

  attr_reader :position

  ##
  # Creates a new, empty History object

  def initialize
    @pages = []
    @position = 0
  end

  ##
  # Travels back one page in the history.  Returns nil if you're at the start
  # of history, returns the content and context otherwise.

  def back
    return if @position == 0

    @position -= 1

    _, content, context = @pages[@position]

    [content, context]
  end

  ##
  # Travels forward one page in the history.  Returns nil if you're at the end
  # of history, returns the content and context otherwise.

  def forward
    return if @position >= @pages.length - 1

    @position += 1

    _, content, context = @pages[@position]

    [content, context]
  end

  ##
  # Goes to +name+ with +content+ and +context+, clearing items in the history
  # ahead of this page.

  def go name, content, context
    @pages.slice! @position + 1, @pages.length unless
      @position == @pages.length

    @pages << [name, content, context]

    @position = @pages.length - 1
  end

  ##
  # The names of pages in the history

  def pages
    @pages.map { |name,| name }
  end

  ##
  # An RDoc::Markup::Document containing items in the history

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

