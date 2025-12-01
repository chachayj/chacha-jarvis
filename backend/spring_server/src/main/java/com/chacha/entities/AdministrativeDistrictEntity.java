package com.chacha.entities;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;
import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "administrative.administrative_districts",
    entityType = EntityType.QUERY_DATAS,
    description = "광역시·도 소속 구(區) 엔터티 (OSM 원본 주요 속성 포함)"
)
@Getter
@Setter
public class AdministrativeDistrictEntity {
    private String  provinceCode;
    private String  provinceName;
    private String  countryCode;
    private String  districtCode;  // KR-SEOUL-SEOCHOGU

    private String  name;          // 구 한글명
    private String  nameEn;        // 구 영문명
    private Integer adminLevel;
    private Long    osmId;
    // private Double  centerLat;
    // private Double  centerLng;

    // geom 등 무거운 필드는 응답에서 제외 (필요 시 별도 API/엔티티)
}
