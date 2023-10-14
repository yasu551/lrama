class Lrama::NewParser
rule
  input: prologue_declarations bison_declarations "%%" grammar epilogue_opt

  prologue_declarations: # empty
                       | prologue_declarations prologue_declaration

  prologue_declaration: "%{"
                          {
                            @lexer.status = :c_declaration
                            @lexer.end_symbol = '%}'
                            @grammar.prologue_first_lineno = @lexer.line
                          }
                        C_DECLARATION
                          {
                            @lexer.status = :initial
                            @lexer.end_symbol = nil
                          }
                        "%}"
                          {
                            @grammar.prologue = prologue(val[2].s_value)
                          }
                      | "%require" STRING

  bison_declarations: /* empty */ { result = "" }
                    | bison_declarations bison_declaration

  bison_declaration: grammar_declaration
                   | "%expect" INTEGER { @grammar.expect = val[1] }
                   | "%define" variable value
                   | "%require" STRING
                   | "%param" params
                   | "%lex-param" params
                       {
                         val[1].each {|token|
                           token.references = []
                           @grammar.lex_param = @grammar.build_code(:lex_param, token).token_code.s_value
                         }
                       }
                   | "%parse-param" params
                       {
                         val[1].each {|token|
                           token.references = []
                           @grammar.parse_param = @grammar.build_code(:parse_param, token).token_code.s_value
                         }
                       }
                   | "%initial-action" "{"
                       {
                         @lexer.status = :c_declaration
                         @lexer.end_symbol = '}'
                       }
                     C_DECLARATION
                       {
                         @lexer.status = :initial
                         @lexer.end_symbol = nil
                       }
                     "}"
                       {
                         @grammar.initial_action = @grammar.build_code(:initial_action, val[3])
                       }
                   | ";"

  grammar_declaration: "%union" "{"
                         {
                           @lexer.status = :c_declaration
                           @lexer.end_symbol = '}'
                         }
                       C_DECLARATION
                         {
                           @lexer.status = :initial
                           @lexer.end_symbol = nil
                         }
                       "}"
                         {
                           @grammar.set_union(@grammar.build_code(:union, val[3]), val[3].line)
                         }
                     | symbol_declaration
                     | "%destructor" "{"
                         {
                           @lexer.status = :c_declaration
                           @lexer.end_symbol = '}'
                         }
                       C_DECLARATION
                         {
                           @lexer.status = :initial
                           @lexer.end_symbol = nil
                         }
                         "}" generic_symlist
                     | "%printer" "{"
                         {
                           @lexer.status = :c_declaration
                           @lexer.end_symbol = '}'
                         }
                       C_DECLARATION
                         {
                           @lexer.status = :initial
                           @lexer.end_symbol = nil
                         }
                       "}" generic_symlist
                         {
                           @grammar.add_printer(ident_or_tags: val[6], code: @grammar.build_code(:printer, val[3]), lineno: val[3].line)
                         }
                     | "%error-token" "{"
                         {
                           @lexer.status = :c_declaration
                           @lexer.end_symbol = '}'
                         }
                       C_DECLARATION
                         {
                           @lexer.status = :initial
                           @lexer.end_symbol = nil
                         }
                       "}" generic_symlist
                         {
                           @grammar.add_error_token(ident_or_tags: val[6], code: @grammar.build_code(:error_token, val[3]), lineno: val[3].line)
                         }

  symbol_declaration: "%token" token_declarations
                    | "%type" symbol_declarations
                        {
                          val[1].each {|hash|
                            hash[:tokens].each {|id|
                              @grammar.add_type(id: id, tag: hash[:tag])
                            }
                          }
                        }
                    | "%left" token_declarations_for_precedence
                        {
                          val[1].each {|hash|
                            hash[:tokens].each {|id|
                              sym = @grammar.add_term(id: id)
                              @grammar.add_left(sym, @precedence_number)
                            }
                          }
                          @precedence_number += 1
                        }
                    | "%right" token_declarations_for_precedence
                        {
                          val[1].each {|hash|
                            hash[:tokens].each {|id|
                              sym = @grammar.add_term(id: id)
                              @grammar.add_right(sym, @precedence_number)
                            }
                          }
                          @precedence_number += 1
                        }
                    | "%nonassoc" token_declarations_for_precedence
                        {
                          val[1].each {|hash|
                            hash[:tokens].each {|id|
                              sym = @grammar.add_term(id: id)
                              @grammar.add_nonassoc(sym, @precedence_number)
                            }
                          }
                          @precedence_number += 1
                        }

  token_declarations: token_declaration_list
                        {
                          val[0].each {|token_declaration|
                            @grammar.add_term(id: token_declaration[0], alias_name: token_declaration[2], token_id: token_declaration[1], tag: nil, replace: true)
                          }
                        }
                    | TAG token_declaration_list
                        {
                          val[1].each {|token_declaration|
                            @grammar.add_term(id: token_declaration[0], alias_name: token_declaration[2], token_id: token_declaration[1], tag: val[0], replace: true)
                          }
                        }
                    | token_declarations TAG token_declaration_list
                        {
                          val[2].each {|token_declaration|
                            @grammar.add_term(id: token_declaration[0], alias_name: token_declaration[2], token_id: token_declaration[1], tag: val[1], replace: true)
                          }
                        }

  token_declaration_list: token_declaration { result = [val[0]] }
                        | token_declaration_list token_declaration { result = val[0].append(val[1]) }

  token_declaration: id int_opt alias { result = val }

  int_opt: # empty
         | INTEGER

  alias: # empty
       | string_as_id
       | STRING

  symbol_declarations: symbol_declaration_list
                         {
                           result = [{tag: nil, tokens: val[0]}]
                         }
                     | TAG symbol_declaration_list
                         {
                           result = [{tag: val[0], tokens: val[1]}]
                         }
                     | symbol_declarations TAG symbol_declaration_list
                       {
                         result = val[0].append({tag: val[1], tokens: val[2]})
                       }

  symbol_declaration_list: symbol { result = [val[0]] }
                         | symbol_declaration_list symbol { result = val[0].append(val[1]) }

  symbol: id
        | string_as_id

  params: params "{"
            {
              @lexer.status = :c_declaration
              @lexer.end_symbol = '}'
            }
          C_DECLARATION
            {
              @lexer.status = :initial
              @lexer.end_symbol = nil
            }
          "}"
            {
              result = val[0].append(val[3])
            }
        | "{"
            {
              @lexer.status = :c_declaration
              @lexer.end_symbol = '}'
            }
          C_DECLARATION
            {
              @lexer.status = :initial
              @lexer.end_symbol = nil
            }
          "}"
            {
              result = [val[2]]
            }

  token_declarations_for_precedence: token_declaration_list_for_precedence
                                       {
                                         result = [{tag: nil, tokens: val[0]}]
                                       }
                                   | TAG token_declaration_list_for_precedence
                                       {
                                         result = [{tag: val[0], tokens: val[1]}]
                                       }
                                   | token_declarations_for_precedence token_declaration_list_for_precedence
                                       {
                                         result = val[0].append({tag: nil, tokens: val[1]})
                                       }

  token_declaration_list_for_precedence: token_declaration_for_precedence { result = [val[0]] }
                                       | token_declaration_list_for_precedence token_declaration_for_precedence { result = val[0].append(val[1]) }

  token_declaration_for_precedence: id

  id: IDENTIFIER { raise "Ident after %prec" if @prec_seen }
    | CHARACTER { raise "Char after %prec" if @prec_seen }

  grammar: rules_or_grammar_declaration
         | grammar rules_or_grammar_declaration

  rules_or_grammar_declaration: rules
                              | grammar_declaration ";"

  rules: id_colon named_ref_opt ":" rhs_list
           {
             lhs = val[0]
             lhs.alias = val[1]
             val[3].each {|hash|
               @grammar.add_rule(lhs: lhs, rhs: hash[:rhs], lineno: hash[:lineno])
             }
           }

  rhs_list: rhs
              {
                result = [{rhs: val[0], lineno: val[0].first&.line || @lexer.line - 1}]
              }
          | rhs_list "|" rhs
              {
                result = val[0].append({rhs: val[2], lineno: val[2].first&.line || @lexer.line - 1})
              }
          | rhs_list ";"

  rhs: /* empty */
         {
           result = []
           @prec_seen = false
           @code_after_prec = false
         }
     | rhs symbol named_ref_opt
         {
           token = val[1]
           val[1].alias = val[2]
           result = val[0].append(token)
         }
     | rhs "{"
         {
           if @prec_seen
             raise "Multiple User_code after %prec" if @code_after_prec
             @code_after_prec = true
           end
           @lexer.status = :c_declaration
           @lexer.end_symbol = '}'
         }
       C_DECLARATION
         {
           @lexer.status = :initial
           @lexer.end_symbol = nil
         }
       "}" named_ref_opt
         {
           token = val[3]
           token.alias = val[6]
           result = val[0].append(token)
         }
     | "{"
         {
           if @prec_seen
             raise "Multiple User_code after %prec" if @code_after_prec
             @code_after_prec = true
           end
           @lexer.status = :c_declaration
           @lexer.end_symbol = '}'
         }
       C_DECLARATION
         {
           @lexer.status = :initial
           @lexer.end_symbol = nil
         }
       "}" named_ref_opt
         {
           token = val[2]
           token.alias = val[5]
           result = [token]
         }
     | rhs "%prec" symbol
         {
           sym = @grammar.find_symbol_by_id!(val[2])
           result = val[0].append(sym)
           @prec_seen = true
         }

  named_ref_opt: # empty
               | '[' IDENTIFIER ']' { result = val[1].s_value }

  id_colon: IDENT_COLON

  epilogue_opt: # empty
              | "%%"
                  {
                    @lexer.status = :c_declaration
                    @lexer.end_symbol = '\Z'
                    @grammar.epilogue_first_lineno = @lexer.line + 1
                  }
                C_DECLARATION
                  {
                    @lexer.status = :initial
                    @lexer.end_symbol = nil
                    @grammar.epilogue = val[2].s_value
                  }

  variable: id

  value: # empty
       | IDENTIFIER
       | STRING
       | "{...}"

  generic_symlist: generic_symlist_item { result = [val[0]] }
                 | generic_symlist generic_symlist_item { result = val[0].append(val[1]) }

  generic_symlist_item: symbol
                      | TAG

  string_as_id: STRING { result = Lrama::Lexer::Token.new(type: Lrama::Lexer::Token::Ident, s_value: val[0]) }
end

---- inner

def initialize(text, include_header)
  @text = text
  @include_header = include_header
end

def parse
  @lexer = Lrama::NewLexer.new(@text)
  @grammar = Lrama::Grammar.new
  @precedence_number = 0
  do_parse
  @grammar.extract_references
  @grammar.prepare
  @grammar.compute_nullable
  @grammar.validate!
  @grammar
end

def next_token
  @lexer.next_token
end

def prologue(s_value)
  if @include_header && !s_value.match?(/^\s*#include\s+"#{@include_header}"/)
    "\n#include \"#{@include_header}\"\n" + s_value
  else
    s_value
  end
end
