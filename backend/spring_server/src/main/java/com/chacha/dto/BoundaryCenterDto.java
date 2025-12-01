package com.chacha.dto;

import com.chacha.entities.BoundaryCenterEntity;
import lombok.Getter;

@Getter
public class BoundaryCenterDto {
    private final String  provinceCode;
    private final Long    id;
    private final Long    osmId;
    private final String  name;
    private final String  nameEn;
    private final String  boundary;
    private final Integer adminLevel;
    private final String  countryCode;

    // private final Long    adminCentreNodeId;
    // private final Double  adminCentreNodeLat;
    // private final Double  adminCentreNodeLng;
    // private final Long    labelNodeId;
    // private final Double  labelNodeLat;
    // private final Double  labelNodeLng;

    private final Double  longitude;
    private final Double  latitude;

    public BoundaryCenterDto(
            String provinceCode, Long id, Long osmId, String name, String nameEn,
            String boundary, Integer adminLevel, String countryCode,
            // Long adminCentreNodeId, Double adminCentreNodeLat, Double adminCentreNodeLng,
            // Long labelNodeId, Double labelNodeLat, Double labelNodeLng,
            Double longitude, Double latitude) {
        this.provinceCode = provinceCode;
        this.id = id;
        this.osmId = osmId;
        this.name = name;
        this.nameEn = nameEn;
        this.boundary = boundary;
        this.adminLevel = adminLevel;
        this.countryCode = countryCode;
        // this.adminCentreNodeId = adminCentreNodeId;
        // this.adminCentreNodeLat = adminCentreNodeLat;
        // this.adminCentreNodeLng = adminCentreNodeLng;
        // this.labelNodeId = labelNodeId;
        // this.labelNodeLat = labelNodeLat;
        // this.labelNodeLng = labelNodeLng;
        this.longitude = longitude;
        this.latitude = latitude;
    }

    public static BoundaryCenterDto fromEntity(BoundaryCenterEntity e) {
        return new BoundaryCenterDto(
            e.getProvinceCode(), e.getId(), e.getOsmId(), e.getName(), e.getNameEn(),
            e.getBoundary(), e.getAdminLevel(), e.getCountryCode(),
            // e.getAdminCentreNodeId(), e.getAdminCentreNodeLat(), e.getAdminCentreNodeLng(),
            // e.getLabelNodeId(), e.getLabelNodeLat(), e.getLabelNodeLng(),
            e.getLongitude(), e.getLatitude()
        );
    }
}
