require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'

require 'lex'

describe TokenEnumerator do

  describe "with an empty lexer" do
    before do
      @lex = TokenEnumerator.new ""
    end

    it("next is EOF") {
      @lex.next.type.must_equal :eof
    }

    it("is empty") {
      @lex.must_be :empty?
    }

    it("front is EOF") {
      @lex.front.type.must_equal :eof
    }
  end

  describe "#comment" do
    it("is correct") {
      TokenEnumerator.new("! foobar").comment.must_equal "! foobar"
    }
  end

  describe "#string_lit" do
    it("is correct") {
      lex = TokenEnumerator.new('"this is a string"  "and so is this"')
      lex.string_lit.must_equal("this is a string")
      lex.next.val.must_equal("and so is this")
      lex.must_be :empty?
    }
  end

  describe "with comments" do
    before do
      @lex = TokenEnumerator.new <<-eof
        ! test comment
        /*
         * block comment
         */
      eof
    end

    it("has two comments") {
      @lex.next.type.must_equal :cmt
      @lex.next.type.must_equal :cmt
      @lex.next.type.must_equal :eof
    }

    it("first comment is 'test comment'") {
      @lex.next.val.must_match(/test comment/)
      @lex.next.val.must_match(/block comment/)
      @lex.next.val.must_equal nil
    }
  end

  describe "slightly more complex tokenization" do
    before do
      @lex = TokenEnumerator.new <<-eof
        ! comment here

        .global foo
        .section ".data"
      eof
    end

    it("is cmt, idt, idt, idt, str") {
      @lex.next.type.must_equal :cmt
      @lex.next.must_equal Token.new(:idt, ".global")
      @lex.next.must_equal Token.new(:idt, "foo")
      @lex.next.must_equal Token.new(:idt, ".section")
      @lex.next.must_equal Token.new(:str, ".data")
      @lex.next.must_equal Token.new(:eof, nil)
    }

    it("front does not modify next") {
      @lex.front.type.must_equal :cmt

      @lex.next.must_equal Token.new(:idt, ".global")
      @lex.front.must_equal Token.new(:idt, ".global")

      @lex.next.must_equal Token.new(:idt, "foo")
      @lex.front.must_equal Token.new(:idt, "foo")

      @lex.next.must_equal Token.new(:idt, ".section")
      @lex.front.must_equal Token.new(:idt, ".section")

      @lex.next.must_equal Token.new(:str, ".data")
      @lex.front.must_equal Token.new(:str, ".data")

      @lex.next.must_equal Token.new(:eof, nil)
      @lex.front.must_equal Token.new(:eof, nil)

    }

    it("can be duplicated and restored") {
      duped = @lex.dup

      duped.front.type.must_equal :cmt
      @lex.front.type.must_equal  :cmt

      @lex.next
      duped.front.type.must_equal :cmt
      @lex.front.type.must_equal  :idt

      @lex.next
      duped.front.type.must_equal :cmt
      @lex.front.type.must_equal  :idt

      @lex.next
      duped.front.type.must_equal :cmt
      @lex.front.type.must_equal  :idt

      @lex.next
      duped.front.type.must_equal :cmt
      @lex.front.type.must_equal  :str
    }
  end

  describe "an oft failing test case" do
    it "works" do
      @lex = TokenEnumerator.new ""
      @lex.instance_variable_set("@front", Token.new(:idt, ".section"))
      @lex.instance_variable_set("@sparc_str", "  \".text\"\n  .global isort\n\nisort:\n  save  %sp, -96, %sp\n\n")
      @lex.next.must_equal Token.new(:str, ".text")
    end
  end

  describe "more complex string" do
    before do
      @lex = TokenEnumerator.new <<-sparc
        /*
         * assembly file isort.s for isort() function, extra credit for
         * CSE 30 PA2 - mycrypt.
         *
         * Performs an insertion sort.
         */

          .section  ".text"
          .global isort

        isort:
          save  %sp, -96, %sp
      sparc
    end

    it("has the right sequence of tokens") {
      [ [:cmt, /Performs/], # block comment
        [:idt, ".section"],
        [:str, ".text"],
        [:idt, ".global"],
        [:idt, "isort"],
        [:idt, "isort"], :cln,
        [:idt, "save"],
        :per, :idt, :cma, # %sp,
        :sub, [:num, "96"], :cma # -96,
      ].each do |type|
        next_tok = @lex.next

        if type.is_a? Array

          if type[1].is_a? Regexp
            next_tok.val.must_match   type[1]
            @lex.front.val.must_match type[1]

          else
            next_tok.val.must_equal   type[1]
            @lex.front.val.must_equal type[1]
          end

          next_tok.type.must_equal type[0]

        else
          next_tok.type.must_equal   type
          @lex.front.type.must_equal type

        end
      end
    }

    it("front does not change the value") {
      @lex.front.type.must_equal :cmt

      @lex.next.must_equal  Token.new(:idt, ".section")
      @lex.front.must_equal Token.new(:idt, ".section")

      @lex.next.must_equal  Token.new(:str, ".text")
      @lex.front.must_equal Token.new(:str, ".text")

      @lex.next.must_equal  Token.new(:idt, ".global")
      @lex.front.must_equal Token.new(:idt, ".global")

      @lex.next.must_equal  Token.new(:idt, "isort")
      @lex.front.must_equal Token.new(:idt, "isort")

      @lex.next.must_equal  Token.new(:idt, "isort")
      @lex.front.must_equal Token.new(:idt, "isort")

      @lex.next.must_equal  Token.new(:cln, ":")
      @lex.front.must_equal Token.new(:cln, ":")
    }
  end

  describe "an oft failing test case" do
    it "works" do
      @lex = TokenEnumerator.new ""
      @lex.instance_variable_set("@front", Token.new(:idt, ".section"))
      @lex.instance_variable_set("@sparc_str",
        "  \".text\"\n  .global isort\n\nisort:\n  save  %sp, -96, %sp\n\n")
      @lex.next.must_equal Token.new(:str, ".text")
    end

    it "underscores work" do
      @lex = TokenEnumerator.new "MY_CONST    =  12"
      @lex.next.must_equal Token.new(:idt, "MY_CONST")
      @lex.next.must_equal Token.new(:asn, "=")
      @lex.next.must_equal Token.new(:num, "12", 12)
    end

    it "parses the full register name" do
      @lex = TokenEnumerator.new "mov MY_CONST, %l3"
      @lex.next.must_equal Token.new(:idt, "mov")
      @lex.next.must_equal Token.new(:idt, "MY_CONST")
      @lex.next.must_equal Token.new(:cma, ",")
      @lex.next.must_equal Token.new(:per, "%")
      @lex.next.must_equal Token.new(:idt, "l3")
    end
  end

  describe "token location" do
    it "has the right row" do
      @lex = TokenEnumerator.new("mov")
      @lex.front.loc.must_equal Location.new(0, 0, nil)
    end

    it "is still right" do
      @lex = TokenEnumerator.new("   mov")
      @lex.front.loc.must_equal Location.new(0, 3, nil)
    end

    it "is right for multiline strings" do
      @lex = TokenEnumerator.new <<-sparc
        line1
        line2
        line3 still_line3
        "line4"


        ! line 5


        line6:
          0x7
          MY_EIGHT
      sparc

      tok = @lex.next
      tok.loc.row.must_equal 0
      tok.val.must_equal "line1"

      tok = @lex.next
      tok.loc.row.must_equal 1
      tok.val.must_equal "line2"

      tok = @lex.next
      tok.loc.row.must_equal 2
      tok.val.must_equal "line3"

      tok = @lex.next
      tok.loc.row.must_equal 2
      tok.val.must_equal "still_line3"

      tok = @lex.next
      tok.loc.row.must_equal 3
      tok.val.must_equal "line4"

      tok = @lex.next
      tok.loc.row.must_equal 6
      tok.val.must_match(/! line 5/)

      tok = @lex.next
      tok.loc.row.must_equal 9
      tok.val.must_equal "line6"
    end
  end

  describe "hex digets" do
    it "lexes them" do
      @lex = TokenEnumerator.new("0xFFFFFF")
      @lex.next.must_equal Token.new(:num, "0xFFFFFF", 0xFFFFFF)
    end
  end

end
