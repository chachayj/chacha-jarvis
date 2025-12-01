package com.chacha.entities;

import com.chacha.annotation.EntityInfo;
import com.chacha.annotation.EntityType;
import lombok.Getter;
import lombok.Setter;

@EntityInfo(
    tableName = "administrative.administrative_boundaries_by_province, administrative.administrative_boundary_centers_by_province",
    entityType = EntityType.BATCH_DATAS,
    description = "행정구역 광역 파티션 내 경계 + 중심점 조인 결과"
)
@Getter
@Setter
public class BoundaryCenterEntity {
    // from administrative_boundaries_by_province
    private String  provinceCode;
    private Long    id;
    private Long    osmId;
    private String  name;
    private String  nameEn;
    private String  boundary;
    private Integer adminLevel;
    private String  countryCode;

    // private Long    adminCentreNodeId;
    // private Double  adminCentreNodeLat;
    // private Double  adminCentreNodeLng;
    // private Long    labelNodeId;
    // private Double  labelNodeLat;
    // private Double  labelNodeLng;

    // from administrative_boundary_centers_by_province
    private Double  longitude;
    private Double  latitude;
}
