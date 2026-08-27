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

/// Storage catalog chain (`data/schema/resource_index.proto` and
/// `generation_resources.proto`, both `package efa.v2`).
pub mod efa_v2 {
    #![allow(dead_code)]
    include!(concat!(env!("OUT_DIR"), "/efa.v2.rs"));
}
