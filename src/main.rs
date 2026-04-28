use clap::Parser;
use pollster::FutureExt;
use wgpu_slang_tonemappers::Args;

fn main() {
    let args = Args::parse();
    wgpu_slang_tonemappers::run(args).block_on().unwrap();
}
