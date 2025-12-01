package com.chacha.controller;

import com.chacha.request.DistrictCentersRequest;
import com.chacha.request.DistrictsRequest;
import com.chacha.response.DistrictCentersListResponse;
import com.chacha.response.DistrictListResponse;
import com.chacha.response.ProvinceCentersListResponse;
import com.chacha.response.ProvinceListResponse;
import com.chacha.dto.PagingDto;
import com.chacha.dto.BoundaryCenterDto;
import com.chacha.dto.DistrictsDTO;
import com.chacha.dto.GetDistrictsDTO;
import com.chacha.dto.ProvinceDto;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.Parameters;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.chacha.domain.AdministrativeService;


import java.util.List;

@Tag(name = "Administrative API", description = "행정구역 정보 API")
@RestController
@RequestMapping("/administrative")
public class AdministrativeController {

    private final AdministrativeService service;

    public AdministrativeController(AdministrativeService service) {
        this.service = service;
    }

    // ------------------------------------------------------------------------
    // 광역시·도 목록 조회
    // ------------------------------------------------------------------------
    @Operation(
        summary = "광역시·도 목록 조회",
        description = "국가 코드(기본 KR)를 기준으로 광역시·도 목록을 반환합니다."
    )
    @Parameters({
        @Parameter(name = "countryCode", description = "국가 코드", required = true, example = "KR")
    })
    @GetMapping(value = "/provinces", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<ProvinceListResponse> listProvinces(
            @RequestParam String countryCode
    ) {
        List<ProvinceDto> provinces = this.service.getProvinces(countryCode);

        ProvinceListResponse body = new ProvinceListResponse();
        body.setTotal(provinces.size());
        body.setProvinces(provinces);

        return ResponseEntity.ok(body);
    }

    // ------------------------------------------------------------------------
    // 광역시·도 내 대표 경계 중심점 조회
    // ------------------------------------------------------------------------
    @Operation(
        summary = "광역시·도 중심점 리스트 조회",
        description = "provinceCode(예: KR-INCHEON)에 속하는 행정경계들의 대표좌표 목록을 반환합니다. limit/offset으로 페이징 가능합니다."
    )
    @Parameters({
        @Parameter(name = "provinceCode", description = "광역시·도 코드", required = true, example = "KR-INCHEON"),
        @Parameter(name = "limit",        description = "조회 최대 건수", example = "10"),
        @Parameter(name = "offset",       description = "조회 시작 위치", example = "0")
    })
    @GetMapping(value = "/provinces/centers", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<ProvinceCentersListResponse> listCentersByProvince(
            @RequestParam String provinceCode,
            @RequestParam(required = false, defaultValue = "10") Integer limit,
            @RequestParam(required = false, defaultValue = "0") Integer offset
    ) {
        int total = this.service.getCentersCount(provinceCode);
        List<BoundaryCenterDto> centers = this.service.getCentersByProvince(provinceCode, limit, offset);

        ProvinceCentersListResponse body = new ProvinceCentersListResponse();
        body.setProvinceCode(provinceCode);
        body.setTotal(total);
        body.setCenters(centers);

        return ResponseEntity.ok(body);
    }

    // ------------------------------------------------------------------------
    // 구(區) 목록 조회
    // ------------------------------------------------------------------------
    @Operation(
        summary = "구(區) 목록 조회",
        description = "provinceCode에 속한 구 목록을 반환합니다. limit/offset으로 페이징 가능합니다."
    )
    @Parameters({
        @Parameter(name = "provinceCode", description = "광역시·도 코드", required = true, example = "KR-SEOUL")
    })
    @GetMapping(value = "/districts", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<DistrictListResponse> listDistricts(
            @ModelAttribute DistrictsRequest request
    ) {
        GetDistrictsDTO dto = new GetDistrictsDTO();
        dto.setProvinceCode(request.getProvinceCode());

        List<DistrictsDTO> districts = this.service.findDistricts(dto);

        DistrictListResponse response = new DistrictListResponse();
        response.setProvinceCode(dto.getProvinceCode());
        response.setDistricts(districts);

        return ResponseEntity.ok(response);
    }

    // ------------------------------------------------------------------------
    // 구 내 동 중심점 리스트 조회
    // ------------------------------------------------------------------------
    @Operation(
        summary = "구 내 동 중심점 리스트 조회",
        description = "districtCode(예: KR-SEOUL-SEOCHOGU)에 속하는 행정동 대표좌표를 반환합니다."
    )
    @Parameters({
        @Parameter(name = "districtCode", description = "구 코드", example = "KR-SEOUL-SEOCHOGU"),
        @Parameter(name = "limit", description = "조회 최대 건수", example = "10"),
        @Parameter(name = "offset", description = "조회 시작 위치", example = "0")
    })
    @GetMapping(value = "/districts/centers", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<DistrictCentersListResponse> listCentersByDistrict(
            @RequestParam String districtCode,
            @RequestParam(required = false, defaultValue = "10") Integer limit,
            @RequestParam(required = false, defaultValue = "0") Integer offset
    ) {
        DistrictCentersRequest request = new DistrictCentersRequest();
        request.setDistrictCode(districtCode);
        request.setLimit(limit);
        request.setOffset(offset);

        List<BoundaryCenterDto> centers = service.getCentersByDistrict(request);

        DistrictCentersListResponse body = new DistrictCentersListResponse();
        body.setDistrictCode(districtCode);
        body.setCenters(centers);

        PagingDto paging = new PagingDto();
        paging.setPage((limit != null && limit > 0) ? (offset / Math.max(limit, 1)) + 1 : 1);

        // body.setPaging(paging);

        return ResponseEntity.ok(body);
    }
}
