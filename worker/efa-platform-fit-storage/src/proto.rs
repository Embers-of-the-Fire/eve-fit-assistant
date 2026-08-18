pub mod fit {
    #![allow(dead_code)]
    include!(concat!(env!("OUT_DIR"), "/fit.rs"));
}

pub mod utils {
    #![allow(dead_code)]
    include!(concat!(env!("OUT_DIR"), "/utils.rs"));
}

pub mod platform_data {
    #![allow(dead_code)]
    include!(concat!(env!("OUT_DIR"), "/platform_data.rs"));
}

pub mod efos {
    #![allow(dead_code)]
    include!(concat!(env!("OUT_DIR"), "/efos.rs"));
}
