package com.chacha.entities;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;
import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "administrative.administrative_provinces",
    entityType = EntityType.TABLE,
    description = "행정구역 광역시·도 마스터 엔티티"
)
@Getter
@Setter
public class ProvinceEntity {
    private String countryCode;   // administrative_provinces.country_code
    private String provinceCode;  // administrative_provinces.province_code
    private String provinceName;  // administrative_provinces.province_name
}
