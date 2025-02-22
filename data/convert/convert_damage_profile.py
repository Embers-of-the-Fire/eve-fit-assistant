from __future__ import annotations
from typing import TypedDict

from cache import ConvertCache
import damage_profile_pb2


class DamageProfileGroup(TypedDict):
    name: str
    profiles: list[DamageProfile]


class DamageProfile(TypedDict):
    name: str
    em: float
    thermal: float
    kinetic: float
    explosive: float


def convert(cache: ConvertCache, external: dict):
    data = damage_profile_pb2.DamageProfiles()

    print("Collecting damage profiles...")

    damage_profiles: dict[int, DamageProfileGroup] = cache.get_patch("damage_profile", "yaml")
    
    for group in damage_profiles:
        g = damage_profile_pb2.DamageProfiles.DamageProfileGroup()
        g.name = group["name"]
        
        for profile in group['profiles']:
            p = damage_profile_pb2.DamageProfiles.DamageProfile()
            p.name = profile['name']
            p.em = profile['em']
            p.thermal = profile['thermal']
            p.kinetic = profile['kinetic']
            p.explosive = profile['explosive']
            g.profiles.append(p)
        data.groups.append(g)
    
    external['damage_profile'] = data
