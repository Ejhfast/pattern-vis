require 'ripper'

def transform(src, mapping = nil)
  ident_hash = Hash.new {|h,k| h[k] = "var"+h.size.to_s}
  mapping = Hash.new{|h,k| h[k] = Hash.new(0)} unless mapping
  tks = Ripper.lex(src)

  # leave alone identifiers if they represent function calls
  def is_function?(tks,i)
    on_dot = (i-1 >= 0 && tks[i-1][1] == :on_period) || (i-2 >= 0 && tks[i-1][1] == :on_sp && tks[i-2][1] == :on_period)
    on_paren = (tks[i+1] && tks[i+1][1] == :on_lparen) || (tks[i+2] && tks[i+1][1] == :on_sp && tks[i+2][1] == :on_lparen)
    arg_things = [:on_ident, :on_symbeg, :on_int, :on_float, :on_ivar, :on_cvar, :on_const, :on_tstring_beg]
    on_args = (tks[i+1] && arg_things.include?(tks[i+1][1])) || (tks[i+2] && tks[i+1][1] == :on_sp && arg_things.include?(tks[i+2][1]))
    on_def = (i-2 >= 0 && tks[i-2][2] == "def")
    (on_dot || on_paren || on_args || on_def)
  end
  # don't transform strings in certain cases
  def special_case_str(tks,i)
    is_require = (i-3 >= 0 && tks[i-3][2] == "require") || (i-2 >= 0 && tks[i-2][2] == "require")
    is_require
  end

  def update(tks, i, mapping, newV)
    mapping[newV.to_s][tks[i][2].to_s] = 1
    tks[i][2] = newV.to_s
  end

  # Rewrite the various sorts of identifiers
  tks.each_index do |i|
    if tks[i][1] == :on_ident && !is_function?(tks,i) && !(tks[i][3] && tks[i][3] == :keep)
      if(tks[i-1] && tks[i-1][1] == :on_symbeg)
        update(tks, i, mapping, "SYMBOL")
      else
        update(tks, i, mapping, ident_hash[tks[i][2]])
      end
    elsif tks[i][1] == :on_gvar
      update(tks, i, mapping, ident_hash["$"+tks[i][2]])
    elsif tks[i][1] == :on_ivar
      update(tks, i, mapping, ident_hash["@"+tks[i][2]])
    elsif tks[i][1] == :on_cvar
      update(tks, i, mapping, ident_hash["@@"+tks[i][2]])
    elsif tks[i][1] == :on_int || tks[i][1] == :on_float
      update(tks, i, mapping, "NUM")
    elsif tks[i][1] == :on_tstring_content && !special_case_str(tks,i)
      update(tks, i, mapping, "STR")
    elsif tks[i-2] && tks[i-2][2] == "def" 
      update(tks, i, mapping, "fun")
      #olds = Array.new
      while tks[i+1] && (tks[i+1][1] != :on_semicolon) && (tks[i+1][1] != :on_nl) && (tks[i+1][1] != :on_ignored_nl) && (tks[i+1][2] != "\n")
        #olds << tks.delete_at(i+1)
        tks.delete_at(i+1)
      end
      tks.insert(i+1,[[1,tks[i][0][1]+1], :on_lparen, "("])
      tks.insert(i+2,[[1,tks[i][0][1]+7], :on_ident, "arglst", :keep])
      tks.insert(i+3,[[1,tks[i][0][1]+7], :on_rparen, ")", :keep])
    elsif tks[i][1] == :on_sp
      tks[i][2] = " "
    elsif tks[i][1] == :on_comment
      ws = tks[i][2].include?("\n") ? "\n" : ""
      tks[i][2] = "# COMMENT" + ws
    end
  end
  return tks.map{|x| x[2]}, mapping
end
