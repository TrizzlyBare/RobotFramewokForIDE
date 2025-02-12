use std::io;

fn main() {
    println!("Enter a value for x:");
    let mut input = String::new();
    io::stdin().read_line(&mut input).expect("Failed to read line");
    
    let x: u32 = input.trim().parse().expect("Please enter a valid number");
    let result: i32 = 2i32.pow(x);
    println!("{}", result);
}