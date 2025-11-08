use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let default_text = "PERFORM UPKEEP".to_string();
    let text = args.get(1).unwrap_or(&default_text);

    let border = "//////////////////////////////////////////////////////////////";

    // Opening line: /* + slashes, NO closing */
    print!("/*");           // only print /*
    println!("{}", border);  // print slashes on the same line

    // Middle line: the header text, manually indented
    println!("                           {}", text.to_uppercase());

    // Bottom line: slashes + closing */
    println!("{}*/", border);
}