(*  This file is part of the ppx_tools package.  It is released  *)
(*  under the terms of the MIT license (see LICENSE file).       *)
(*  Copyright 2013  Alain Frisch and LexiFi                      *)

open Parsetree
open Asttypes
open Location
open Ast_helper


module Label = struct

  type t = string

  type desc =
      Nolabel
    | Labelled of string
    | Optional of string

  let explode s =
    if s = "" then Nolabel
    else if s.[0] = '?' then Optional (String.sub s 1 (String.length s - 1))
    else Labelled s

  let nolabel = ""
  let labelled s = s
  let optional s = "?"^s

end

module Constant = struct 
  let get_char = function Const_char c -> Some c | _ -> None 
  let get_int = function Const_int i -> Some i | _ -> None
  let get_str = function Const_string(s, _) -> Some s | _ -> None 
end 

let may_tuple tup = function
  | [] -> None
  | [x] -> Some x
  | l -> Some (tup ?loc:None ?attrs:None l)

let lid s = mkloc (Longident.parse s) !default_loc
let constr s args = Exp.construct (lid s) (may_tuple Exp.tuple args)
let nil () = constr "[]" []
let unit () = constr "()" []
let tuple l = match l with [] -> unit () | [x] -> x | xs -> Exp.tuple xs
let cons hd tl = constr "::" [hd; tl]
let list l = List.fold_right cons l (nil ())
let str s = Exp.constant (Const_string (s, None))
let int x = Exp.constant (Const_int x)
let char x = Exp.constant (Const_char x)
let float x = Exp.constant (Const_float (string_of_float x))
let record ?over l =
  Exp.record (List.map (fun (s, e) -> (lid s, e)) l) over
let func l = Exp.function_ (List.map (fun (p, e) -> Exp.case p e) l)
let lam ?(label = Label.nolabel) ?default pat exp = Exp.fun_ label default pat exp
let app f l = if l = [] then f else Exp.apply f (List.map (fun a -> Label.nolabel, a) l)
let evar s = Exp.ident (lid s)
let let_in ?(recursive = false) b body =
  Exp.let_ (if recursive then Recursive else Nonrecursive) b body

let sequence = function
  | [] -> unit ()
  | hd :: tl -> List.fold_left (fun e1 e2 -> Exp.sequence e1 e2) hd tl

let pvar s = Pat.var (mkloc s !default_loc)
let pconstr s args = Pat.construct (lid s) (may_tuple Pat.tuple args)
let precord ?(closed = Open) l =
  Pat.record (List.map (fun (s, e) -> (lid s, e)) l) closed
let pnil () = pconstr "[]" []
let pcons hd tl = pconstr "::" [hd; tl]
let punit () = pconstr "()" []
let ptuple l = match l with [] -> punit () | [x] -> x | xs -> Pat.tuple xs
let plist l = List.fold_right pcons l (pnil ())

let pstr s = Pat.constant (Const_string (s, None))
let pint x = Pat.constant (Const_int x)
let pchar x = Pat.constant (Const_char x)
let pfloat x = Pat.constant (Const_float (string_of_float x))

let tconstr c l = Typ.constr (lid c) l

let get_str = function
  | {pexp_desc=Pexp_constant (Const_string (s, _)); _} -> Some s
  | _ -> None

let get_str_with_quotation_delimiter = function
  | {pexp_desc=Pexp_constant (Const_string (s, d)); _} -> Some (s, d)
  | _ -> None

let get_lid = function
  | {pexp_desc=Pexp_ident{txt=id;_};_} ->
      Some (String.concat "." (Longident.flatten id))
  | _ -> None

let find_attr s attrs =
  try Some (snd (List.find (fun (x, _) -> x.txt = s) attrs))
  with Not_found -> None

let expr_of_payload = function
  | PStr [{pstr_desc=Pstr_eval(e, _); _}] -> Some e
  | _ -> None

let find_attr_expr s attrs =
  match find_attr s attrs with
  | Some e -> expr_of_payload e
  | None -> None

let has_attr s attrs =
  find_attr s attrs <> None
