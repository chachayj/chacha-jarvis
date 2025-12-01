package com.chacha.dto;

import com.chacha.entities.BoundaryCenterEntity;
import lombok.Getter;

import java.util.List;
import java.util.stream.Collectors;

@Getter
public class ProvinceBoundaryCentersBatchDto {
    private final String provinceCode;
    private final List<BoundaryCenterDto> centers;

    public ProvinceBoundaryCentersBatchDto(String provinceCode, List<BoundaryCenterDto> centers) {
        this.provinceCode = provinceCode;
        this.centers = centers;
    }

    public static ProvinceBoundaryCentersBatchDto fromEntities(String provinceCode, List<BoundaryCenterEntity> rows) {
        List<BoundaryCenterDto> mapped = rows.stream()
                .map(BoundaryCenterDto::fromEntity)
                .collect(Collectors.toList());
        return new ProvinceBoundaryCentersBatchDto(provinceCode, mapped);
    }
}
