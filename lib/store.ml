module List = Base.List
module Hashtbl = Base.Hashtbl

type t = {boxes: Box.t list} 
[@@deriving show, yojson {exn = true}]


let store_path = 
  try Sys.getenv "STORE_PATH" with
  | Not_found -> 
    let app_dir = ".config/prep" in
    let store_name = "store.json" in
    let home = Sys.getenv "HOME" in
    Fmt.str "%s/%s/%s" home app_dir store_name

let load () = 
  let json_value = Yojson.Safe.from_file store_path in
  let boxes = of_yojson_exn json_value in
  boxes

let save store =
  let boxes_json = to_yojson store in
  Yojson.Safe.to_file store_path boxes_json


let add_box box store =
  {
    boxes =
      List.sort (box :: store.boxes) ~compare:(fun a b ->
          Interval.compare a.interval b.interval);
  }

let add card ?(at = 0) store =
  let rec add i boxes =
    match boxes with
    | [] -> [Box.add card (Box.create (Interval.Day 1))]
    | boxe :: boxes ->
      if i = at then Box.add card boxe :: boxes
      else boxe :: add (i - 1) boxes
  in
  let boxes = add 0 store.boxes in
  {boxes}

let all_cards store =
  List.bind store.boxes ~f:(fun box -> box.cards)

let find_card card_id store =
  let is_equal a b =
    Str.string_partial_match
      (Str.regexp (String.lowercase_ascii a))
      (String.lowercase_ascii b) 0
  in
  let matches =
    List.foldi store.boxes ~init:[] ~f:(fun i acc box ->
        let matches =
          List.filter box.cards ~f:(fun card -> is_equal card_id card.id)
          |> List.map ~f:(fun card -> (i, card))
        in
        acc @ matches)
  in
  match matches with [] -> None | [x] -> Some x | _ -> None





  (* let box_cards =   *)
  (*   List.foldi *)
  (*     store.boxes *)
  (*     ~init:(Hashtbl.Poly.create ())  *)
  (*     ~f:(fun i table box ->  *)
  (*         List.iter box.cards ~f:(fun card ->  *)
  (*             Hashtbl.add table ~key:card.id ~data:(i, card) |> ignore *)
  (*           ) ; *)
  (*         table) in *)
  (* Hashtbl.find box_cards card_id *)

exception Business_error

let find_card_exn card_id store =
  match find_card card_id store with
  | Some result -> result
  | None ->
    Console.(print_error "No card found with id %a" yellow_s card_id);
    raise Caml.Not_found


let exists card_id store =
  let result = find_card card_id store in
  match result with
  | Some _ -> true
  | None -> false


let move_card_to to_box card_id store =
  let boxes_count = List.length store.boxes in
  let from_box, card = find_card_exn card_id store in
  let to_box = 
    if to_box < 0 then 0 
    else if to_box >= boxes_count then 
      (boxes_count - 1) 
    else to_box 
  in
  let boxes =
    List.mapi store.boxes ~f:(fun i box ->
        let box = 
          if i = from_box then Box.remove card_id box
          else box in

        if i = to_box then
          Box.add {card with last_reviewed_at = Unix.time ()} box
        else box
      )
  in
  {boxes}


let empty_store () =
  {boxes = []}

let default_store () =
  empty_store ()
  |> add_box @@ Box.create @@ Day 3
  |> add_box @@ Box.create @@ Week 1
  |> add_box @@ Box.create @@ Day 8
  |> add_box @@ Box.create @@ Week 6


let init () =
  if Sys.file_exists store_path then ()
  else
    begin
      Util.mkdir_p (Filename.dirname store_path) 0o777;
      default_store () |> save
    end
