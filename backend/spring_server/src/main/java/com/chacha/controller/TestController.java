package com.chacha.controller;

import com.chacha.mapper.TestMapper;
import com.chacha.domain.SimpleValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestController {

    private final TestMapper testMapper;

    public TestController(TestMapper testMapper) {
        this.testMapper = testMapper;
    }

    @GetMapping("/api/test")
    public SimpleValue test() {
        return testMapper.selectOne();
    }
}
