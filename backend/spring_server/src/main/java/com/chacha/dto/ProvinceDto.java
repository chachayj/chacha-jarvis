package com.chacha.dto;

import com.chacha.entities.ProvinceEntity;
import lombok.Getter;

@Getter
public class ProvinceDto {
    private final String countryCode;
    private final String provinceCode;
    private final String provinceName;

    public ProvinceDto(String countryCode, String provinceCode, String provinceName) {
        this.countryCode = countryCode;
        this.provinceCode = provinceCode;
        this.provinceName = provinceName;
    }

    public static ProvinceDto fromEntity(ProvinceEntity e) {
        return new ProvinceDto(e.getCountryCode(), e.getProvinceCode(), e.getProvinceName());
    }
}
