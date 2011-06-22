require 'rdoc/markup/to_rdoc'

class RDoc::Markup::ToCurses < RDoc::Markup::Formatter

  CLASS_REGEXP_STR = RDoc::Markup::ToHtmlCrossref::CLASS_REGEXP_STR
  METHOD_REGEXP_STR = RDoc::Markup::ToHtmlCrossref::METHOD_REGEXP_STR

  attr_reader :window # :nodoc:
  attr_accessor :indent # :nodoc:
  attr_accessor :prefix # :nodoc:

  def initialize window, context, driver, markup = nil
    super markup

    @width = Curses.cols - 2
    @window = window
    @context = context
    @driver = driver
    init_tags

    green_pair = Curses.color_pair Curses::COLOR_GREEN
    @heading_style = {}
    @heading_style.default = Curses::A_NORMAL | green_pair
    @heading_style[1] = Curses::A_BOLD        | green_pair
    @heading_style[2] = Curses::A_UNDERLINE   | green_pair

    @heading_color = Curses::COLOR_GREEN
  end

  ##
  # Maps RDoc attributes to Curses attributes

  def init_tags
    add_tag :BOLD, [true, Curses::A_BOLD],      [false, Curses::A_BOLD]
    add_tag :TT,   [true, Curses::A_NORMAL],    [false, Curses::A_NORMAL]
    add_tag :EM,   [true, Curses::A_UNDERLINE], [false, Curses::A_UNDERLINE]

    @markup.add_special(/\\\S/, :SUPPRESSED_CROSSREF)
    @markup.add_special RDoc::Markup::ToHtmlCrossref::CROSSREF_REGEXP, :CROSSREF
  end

  # :section: Visitor

  ##
  # Adds +blank_line+ to the output

  def accept_blank_line blank_line
    @res << newline
  end

  ##
  # Adds +heading+ to the output

  def accept_heading heading
    use_prefix or @res << ' ' * @indent

    @window.attron @heading_style[heading.level] do
      @res << heading.text
    end

    @res << newline
  end

  ##
  # Adds +paragraph+ to the output

  def accept_indented_paragraph paragraph
    @indent += paragraph.indent
    convert_flow attributes paragraph.text
    @indent -= paragraph.indent
    @res << newline
  end

  ##
  # Finishes consumption of +list+

  def accept_list_end list
    @list_index.pop
    @list_type.pop
    @list_width.pop
  end

  ##
  # Finishes consumption of +list_item+

  def accept_list_item_end list_item
    width = case @list_type.last
            when :BULLET then
              2
            when :NOTE, :LABEL then
              @res << newline
              2
            else
              bullet = @list_index.last.to_s
              @list_index[-1] = @list_index.last.succ
              bullet.length + 2
            end

    @indent -= width
  end

  ##
  # Prepares the visitor for consuming +list_item+

  def accept_list_item_start list_item
    type = @list_type.last

    case type
    when :NOTE, :LABEL then
      bullet = attributes(list_item.label) << ":\n"
      @prefix = [' ' * @indent]
      @indent += 2
      @prefix.concat bullet
      @prefix << ' ' * @indent
    else
      bullet = type == :BULLET ? '*' :  @list_index.last.to_s + '.'
      @prefix = [' ' * @indent, bullet.ljust(bullet.length + 1)]
      width = bullet.length + 1
      @indent += width
    end
  end

  ##
  # Prepares the visitor for consuming +list+

  def accept_list_start list
    case list.type
    when :BULLET then
      @list_index << nil
      @list_width << 1
    when :LABEL, :NOTE then
      @list_index << nil
      @list_width << 2
    when :LALPHA then
      @list_index << 'a'
      @list_width << list.items.length.to_s.length
    when :NUMBER then
      @list_index << 1
      @list_width << list.items.length.to_s.length
    when :UALPHA then
      @list_index << 'A'
      @list_width << list.items.length.to_s.length
    else
      raise RDoc::Error, "invalid list type #{list.type}"
    end

    @list_type << list.type
  end

  ##
  # Adds +paragraph+ to the output

  def accept_paragraph paragraph
    convert_flow attributes paragraph.text
    @res << newline
  end

  ##
  # Adds +rule+ to the output

  def accept_rule rule
    use_prefix or @res << ' ' * @indent
    @res << '-' * (@width - @indent)
    @res << newline
  end

  ##
  # Outputs +verbatim+ indented 2 columns

  def accept_verbatim verbatim
    indent = ' ' * (@indent + 2)

    verbatim.parts.each do |part|
      @res << indent unless part == "\n"
      @res << part
    end

    @newlines += verbatim.parts.count "\n"

    @res << newline
  end

  ##
  # Returns the generated output

  def end_accepting
    # do nothing
  end

  ##
  # Prepares the visitor for text generation

  def start_accepting
    @res = @window
    @indent = 0
    @prefix = nil
    @newlines = 1

    @list_index = []
    @list_type  = []
    @list_width = []
  end

  ##
  # Generates links between cross-references in the output.

  def handle_special_CROSSREF special
    name = special.text

    lookup = name

    if /#{CLASS_REGEXP_STR}([.#]|::)#{METHOD_REGEXP_STR}/ =~ lookup then
      #type = $2
      #type = '' if type == '.'  # will find either #method or ::method
      #method = "#{type}#{$3}"
      #container = @context.find_symbol_module($1)
    elsif /^([.#]|::)#{METHOD_REGEXP_STR}/ =~ lookup then
      #type = $1
      #type = '' if type == '.'
      #method = "#{type}#{$2}"
      #container = @context
    else
      container = nil
    end

    if container then # method
    else
      ref = @driver.find_module_named lookup
    end

    if ref then
      @window.links << [@window.cury, @window.curx, lookup]

      @res.attron @driver.link_style do
        @res << lookup
      end
    else
      @res << lookup
    end
  end

  # :section: Utilities

  ##
  # Sets attributes for the next text to output based on +tag+

  def annotate tag
    enable, attr = tag

    if enable then
      @res.attron attr
    else
      @res.attroff attr
    end

    nil
  end

  def attributes text
    @am.flow text.dup
  end

  def convert_flow flow
    flow.each do |item|
      case item
      when String then
        wrap item
      when RDoc::Markup::AttrChanger then
        off_tags @res, item
        on_tags @res, item
      when RDoc::Markup::Special then
        use_prefix
        # this doesn't wrap as our specials shouldn't have word breaks
        @res << newline if item.text.length + @window.curx > @width
        @res << ' ' * @indent if @window.curx == 0
        convert_special item
      else
        raise "Unknown flow element #{item.class}: #{item.inspect}"
      end
    end

    nil
  end

  ##
  # Adds a newline to the output and keeps track of the number output for
  # resizing the window

  def newline
    @newlines += 1
    @window.resize @newlines, @window.maxx if @newlines >= @window.maxy
    "\n"
  end

  ##
  # Adds the stored #prefix to the output and clears it.  Lists generate a
  # prefix for later consumption.

  def use_prefix
    prefix = @prefix
    @prefix = nil
    convert_flow prefix if prefix

    prefix
  end

  ##
  # Wraps +text+ to the width set for this formatter.  This version of wrap is
  # smart about the current cursor position.

  def wrap text
    return unless text && !text.empty?

    out = []

    text_len = @width - @indent

    text_len = 20 if text_len < 20

    re = /^(.{0,#{text_len}})[ \n]/
    next_prefix = ' ' * @indent

    prefix = @prefix || next_prefix
    @prefix = nil

    if @window.cury == 0 then
      out << prefix
    else
      out << wrap_first_line(text, text_len, next_prefix)
    end

    while text.length > text_len
      if text =~ re then
        out << $1
        text.slice!(0, $&.length)
      else
        out << text.slice!(0, text_len)
      end

      out << newline << next_prefix
    end

    if text.empty? then
      out.pop
      out.pop
      @newlines -= 1
    else
      out << text
    end

    @res << out.join
  end

  ##
  # Wraps the first line based on the current cursor position to fit within
  # +text_len+ columns.  If the line is wrapped +text+ is modified and
  # +next_prefix+ is added to the output stream.

  def wrap_first_line text, text_len, next_prefix
    text_len = text_len - @window.curx

    return nil if text.length < text_len

    out = []

    if text =~ /^(.{0,#{text_len}})[ \n]/ then
      out << $1
      text.slice!(0, $&.length)
    else
      out << text.slice!(0, text_len)
    end

    out << newline << next_prefix

    out
  end

end

