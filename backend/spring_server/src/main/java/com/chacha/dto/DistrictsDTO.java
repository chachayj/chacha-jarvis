package com.chacha.dto;

import com.chacha.entities.AdministrativeDistrictEntity;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.*;

@Schema(description = "구(區) DTO")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class DistrictsDTO {

    @Schema(description = "구 코드", example = "KR-SEOUL-SEOCHOGU")
    private String districtCode;

    @Schema(description = "구 한글명", example = "서초구")
    private String name;

    @Schema(description = "구 영문명", example = "Seocho-gu")
    private String nameEn;

    @Schema(description = "OSM admin level", example = "6")
    private Integer adminLevel;

    @Schema(description = "국가 코드", example = "KR")
    private String countryCode;

    @Schema(description = "OSM ID", example = "1234567")
    private Long osmId;

    // @Schema(description = "대표 위도", example = "37.476")
    // private Double latitude;

    // @Schema(description = "대표 경도", example = "127.037")
    // private Double longitude;

    public static DistrictsDTO fromEntity(AdministrativeDistrictEntity districtsEntity) {
        DistrictsDTO districts = new DistrictsDTO();
        districts.setDistrictCode(districtsEntity.getDistrictCode());
        districts.setName(districtsEntity.getName());
        districts.setNameEn(districtsEntity.getNameEn());
        districts.setAdminLevel(districtsEntity.getAdminLevel());
        districts.setCountryCode(districtsEntity.getCountryCode());
        districts.setOsmId(districtsEntity.getOsmId());
        // districts.setLatitude(districtsEntity.getCenterLat());
        // districts.setLongitude(districtsEntity.getCenterLng());
        return districts;
    }
}
